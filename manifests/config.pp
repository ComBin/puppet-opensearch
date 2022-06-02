# This class exists to coordinate all configuration related actions,
# functionality and logical units in a central place.
#
# It is not intended to be used directly by external resources like node
# definitions or other modules.
#
# @example importing this class into other classes to use its functionality:
#   class { 'opensearch::config': }
#
# @author Richard Pijnenburg <richard.pijnenburg@opensearch.com>
# @author Tyler Langlois <tyler.langlois@elastic.co>
# @author Gavin Williams <gavin.williams@elastic.co>
#
class opensearch::config {
  #### Configuration

  Exec {
    path => ['/bin', '/usr/bin', '/usr/local/bin'],
    cwd  => '/',
  }

  $init_defaults = {
    'MAX_OPEN_FILES' => '65535',
  }.merge($opensearch::init_defaults)

  if ($opensearch::ensure == 'present') {
    file {
      $opensearch::homedir:
        ensure => 'directory',
        group  => $opensearch::opensearch_group,
        owner  => $opensearch::opensearch_user;
      $opensearch::configdir:
        ensure => 'directory',
        group  => $opensearch::opensearch_group,
        owner  => $opensearch::opensearch_user,
        mode   => '2750';
      $opensearch::datadir:
        ensure => 'directory',
        group  => $opensearch::opensearch_group,
        owner  => $opensearch::opensearch_user,
        mode   => '2750';
      $opensearch::logdir:
        ensure => 'directory',
        group  => $opensearch::opensearch_group,
        owner  => $opensearch::opensearch_user,
        mode   => '2750';
      $opensearch::real_plugindir:
        ensure => 'directory',
        group  => $opensearch::opensearch_group,
        owner  => $opensearch::opensearch_user,
        mode   => 'o+Xr';
      "${opensearch::homedir}/lib":
        ensure  => 'directory',
        group   => '0',
        owner   => 'root',
        recurse => true;
    }

    # Defaults file, either from file source or from hash to augeas commands
    if ($opensearch::init_defaults_file != undef) {
      file { "${opensearch::defaults_location}/opensearch":
        ensure => $opensearch::ensure,
        source => $opensearch::init_defaults_file,
        owner  => 'root',
        group  => $opensearch::opensearch_group,
        mode   => '0660',
        before => Service['opensearch'],
        notify => $opensearch::_notify_service,
      }
    } else {
      augeas { "${opensearch::defaults_location}/opensearch":
        incl    => "${opensearch::defaults_location}/opensearch",
        lens    => 'Shellvars.lns',
        changes => template("${module_name}/etc/sysconfig/defaults.erb"),
        before  => Service['opensearch'],
        notify  => $opensearch::_notify_service,
      }
    }

    # Generate config file
    $_config = deep_implode($opensearch::config)

    # Generate SSL config
    if $opensearch::ssl {
      if ($opensearch::keystore_password == undef) {
        fail('keystore_password required')
      }

      if ($opensearch::keystore_path == undef) {
        $_keystore_path = "${opensearch::configdir}/opensearch.ks"
      } else {
        $_keystore_path = $opensearch::keystore_path
      }

      # Set the correct xpack. settings based on ES version
      if (versioncmp($opensearch::version, '7') >= 0) {
        $_tls_config = {
          'xpack.security.http.ssl.enabled'                => true,
          'xpack.security.http.ssl.keystore.path'          => $_keystore_path,
          'xpack.security.http.ssl.keystore.password'      => $opensearch::keystore_password,
          'xpack.security.transport.ssl.enabled'           => true,
          'xpack.security.transport.ssl.keystore.path'     => $_keystore_path,
          'xpack.security.transport.ssl.keystore.password' => $opensearch::keystore_password,
        }
      }
      else {
        $_tls_config = {
          'xpack.security.transport.ssl.enabled' => true,
          'xpack.security.http.ssl.enabled'      => true,
          'xpack.ssl.keystore.path'              => $_keystore_path,
          'xpack.ssl.keystore.password'          => $opensearch::keystore_password,
        }
      }

      # Trust CA Certificate
      java_ks { 'opensearch_ca':
        ensure       => 'latest',
        certificate  => $opensearch::ca_certificate,
        target       => $_keystore_path,
        password     => $opensearch::keystore_password,
        trustcacerts => true,
      }

      # Load node certificate and private key
      java_ks { 'opensearch_node':
        ensure      => 'latest',
        certificate => $opensearch::certificate,
        private_key => $opensearch::private_key,
        target      => $_keystore_path,
        password    => $opensearch::keystore_password,
      }
    } else {
      $_tls_config = {}
    }

    # # Logging file or hash
    # if ($opensearch::logging_file != undef) {
    #   $_log4j_content = undef
    # } else {
    #   if ($opensearch::logging_template != undef ) {
    #     $_log4j_content = template($opensearch::logging_template)
    #   } else {
    #     $_log4j_content = template("${module_name}/etc/opensearch/log4j2.properties.erb")
    #   }
    #   $_logging_source = undef
    # }
    # file {
    #   "${opensearch::configdir}/log4j2.properties":
    #     ensure  => file,
    #     content => $_log4j_content,
    #     source  => $_logging_source,
    #     mode    => '0644',
    #     notify  => $opensearch::_notify_service,
    #     require => Class['opensearch::package'],
    #     before  => Class['opensearch::service'],
    # }

    # Generate Opensearch config
    $_es_config = merge(
      $opensearch::config,
      { 'path.data' => $opensearch::datadir },
      { 'path.logs' => $opensearch::logdir },
      $_tls_config
    )

    datacat_fragment { 'main_config':
      target => "${opensearch::configdir}/opensearch.yml",
      data   => $_es_config,
    }

    datacat { "${opensearch::configdir}/opensearch.yml":
      template => "${module_name}/etc/opensearch/opensearch.yml.erb",
      notify   => $opensearch::_notify_service,
      require  => Class['opensearch::package'],
      owner    => $opensearch::opensearch_user,
      group    => $opensearch::opensearch_group,
      mode     => '0440',
    }

    if ($opensearch::version != false and versioncmp($opensearch::version, '7.7.0') >= 0) {
      # https://www.elastic.co/guide/en/opensearch/reference/master/advanced-configuration.html#set-jvm-options
      # https://github.com/elastic/opensearch/pull/51882
      # >> "Do not modify the root jvm.options file. Use files in jvm.options.d/ instead."
      $_epp_hash = {
        sorted_jvm_options => sort(unique($opensearch::jvm_options)),
      }
      file { "${opensearch::configdir}/jvm.options.d/jvm.options":
        ensure  => 'file',
        content => epp("${module_name}/etc/opensearch/jvm.options.d/jvm.options.epp", $_epp_hash),
        owner   => $opensearch::opensearch_user,
        group   => $opensearch::opensearch_group,
        mode    => '0640',
        notify  => $opensearch::_notify_service,
      }
    }
    else {
      # Add any additional JVM options
      $opensearch::jvm_options.each |String $jvm_option| {
        file_line { "jvm_option_${jvm_option}":
          ensure => present,
          path   => "${opensearch::configdir}/jvm.options",
          line   => $jvm_option,
          notify => $opensearch::_notify_service,
        }
      }
    }

    if $opensearch::system_key != undef {
      file { "${opensearch::configdir}/system_key":
        ensure => 'file',
        source => $opensearch::system_key,
        mode   => '0400',
      }
    }

    # Add secrets to keystore
    if $opensearch::secrets != undef {
      opensearch_keystore { 'opensearch_secrets':
        configdir => $opensearch::configdir,
        purge     => $opensearch::purge_secrets,
        settings  => $opensearch::secrets,
        notify    => $opensearch::_notify_service,
      }
    }
  } elsif ( $opensearch::ensure == 'absent' ) {
    file { $opensearch::real_plugindir:
      ensure => 'absent',
      force  => true,
      backup => false,
    }

    file { "${opensearch::defaults_location}/opensearch":
      ensure    => 'absent',
      subscribe => Service['opensearch'],
    }
  }
}
