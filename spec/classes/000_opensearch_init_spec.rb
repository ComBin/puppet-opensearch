# frozen_string_literal: true

require 'spec_helper'

describe 'opensearch', type: 'class' do
  default_params = {
    config: { 'node.name' => 'foo' }
  }

  # rubocop:disable RSpec/MultipleMemoizedHelpers
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      case facts[:os]['family']
      when 'Debian'
        let(:defaults_path) { '/etc/default' }
        let(:system_service_folder) { '/lib/systemd/system' }
        let(:pkg_ext) { 'deb' }
        let(:pkg_prov) { 'dpkg' }
        let(:version_add) { '' }

        if (facts[:os]['name'] == 'Debian' && \
           facts[:os]['release']['major'].to_i >= 8) || \
           (facts[:os]['name'] == 'Ubuntu' && \
           facts[:os]['release']['major'].to_i >= 15)
          let(:systemd_service_path) { '/lib/systemd/system' }

          test_pid = true
        else
          test_pid = false
        end
      when 'RedHat'
        let(:defaults_path) { '/etc/sysconfig' }
        let(:system_service_folder) { '/lib/systemd/system' }
        let(:pkg_ext) { 'rpm' }
        let(:pkg_prov) { 'rpm' }
        let(:version_add) { '-1' }

        if facts[:os]['release']['major'].to_i >= 7
          let(:systemd_service_path) { '/lib/systemd/system' }

          test_pid = true
        else
          test_pid = false
        end
      when 'Suse'
        let(:defaults_path) { '/etc/sysconfig' }
        let(:pkg_ext) { 'rpm' }
        let(:pkg_prov) { 'rpm' }
        let(:version_add) { '-1' }

        if facts[:os]['name'] == 'OpenSuSE' &&
           facts[:os]['release']['major'].to_i <= 12
          let(:systemd_service_path) { '/lib/systemd/system' }
        else
          let(:systemd_service_path) { '/usr/lib/systemd/system' }
        end
      end

      let(:facts) do
        facts.merge('scenario' => '', 'common' => '', 'opensearch' => {})
      end

      let(:params) do
        default_params.merge({})
      end

      it { is_expected.to compile.with_all_deps }

      # Varies depending on distro
      it { is_expected.to contain_augeas("#{defaults_path}/opensearch") }

      # Systemd-specific files
      if test_pid == true
        it {
          expect(subject).to contain_service('opensearch').with(
            ensure: 'running',
            enable: true
          )
        }
      end

      context 'java installation' do
        let(:pre_condition) do
          <<-MANIFEST
            include ::java
          MANIFEST
        end

        it {
          expect(subject).to contain_class('opensearch::config').
            that_requires('Class[java]')
        }
      end

      context 'package installation' do
        context 'via repository' do
          context 'with specified version' do
            let(:params) do
              default_params.merge(
                version: '1.0'
              )
            end

            it {
              expect(subject).to contain_package('opensearch').
                with(ensure: "1.0#{version_add}")
            }
          end

          if facts[:os]['family'] == 'RedHat'
            context 'Handle special CentOS/RHEL package versioning' do
              let(:params) do
                default_params.merge(
                  version: '1.1-2'
                )
              end

              it {
                expect(subject).to contain_package('opensearch').
                  with(ensure: '1.1-2')
              }
            end
          end
        end

        context 'when setting package version and package_url' do
          let(:params) do
            default_params.merge(
              version: '0.90.10',
              package_url: "puppet:///path/to/some/es-0.90.10.#{pkg_ext}"
            )
          end

          it { is_expected.to raise_error(Puppet::Error) }
        end

        context 'via package_url setting' do
          ['file:/', 'ftp://', 'http://', 'https://', 'puppet:///'].each do |schema|
            context "using #{schema} schema" do
              let(:params) do
                default_params.merge(
                  package_url: "#{schema}domain-or-path/pkg.#{pkg_ext}"
                )
              end

              unless schema.start_with? 'puppet'
                it {
                  expect(subject).to contain_exec('create_package_dir_opensearch').
                    with(command: 'mkdir -p /opt/opensearch/swdl')
                }

                it {
                  expect(subject).to contain_file('/opt/opensearch/swdl').
                    with(
                      purge: false,
                      force: false,
                      require: 'Exec[create_package_dir_opensearch]'
                    )
                }
              end

              case schema
              when 'file:/'
                it {
                  expect(subject).to contain_file(
                    "/opt/opensearch/swdl/pkg.#{pkg_ext}"
                  ).with(
                    source: "/domain-or-path/pkg.#{pkg_ext}",
                    backup: false
                  )
                }
              when 'puppet:///'
                it {
                  expect(subject).to contain_file(
                    "/opt/opensearch/swdl/pkg.#{pkg_ext}"
                  ).with(
                    source: "#{schema}domain-or-path/pkg.#{pkg_ext}",
                    backup: false
                  )
                }
              else
                [true, false].each do |verify_certificates|
                  context "with download_tool_verify_certificates '#{verify_certificates}'" do
                    let(:params) do
                      default_params.merge(
                        package_url: "#{schema}domain-or-path/pkg.#{pkg_ext}",
                        download_tool_verify_certificates: verify_certificates
                      )
                    end

                    flag = verify_certificates ? '' : ' --no-check-certificate'

                    it {
                      expect(subject).to contain_exec('download_package_opensearch').
                        with(
                          command: "wget#{flag} -O /opt/opensearch/swdl/pkg.#{pkg_ext} #{schema}domain-or-path/pkg.#{pkg_ext} 2> /dev/null",
                          require: 'File[/opt/opensearch/swdl]'
                        )
                    }
                  end
                end
              end

              it {
                expect(subject).to contain_package('opensearch').
                  with(
                    ensure: 'present',
                    source: "/opt/opensearch/swdl/pkg.#{pkg_ext}",
                    provider: pkg_prov
                  )
              }
            end
          end

          context 'using http:// schema with proxy_url' do
            let(:params) do
              default_params.merge(
                package_url: "http://www.domain.com/package.#{pkg_ext}",
                proxy_url: 'http://proxy.example.com:12345/'
              )
            end

            it {
              expect(subject).to contain_exec('download_package_opensearch').
                with(
                  environment: [
                    'use_proxy=yes',
                    'http_proxy=http://proxy.example.com:12345/',
                    'https_proxy=http://proxy.example.com:12345/'
                  ]
                )
            }
          end
        end
      end

      context 'when setting the module to absent' do
        let(:params) do
          default_params.merge(
            ensure: 'absent'
          )
        end

        case facts[:os]['family']
        when 'Suse'
          it {
            expect(subject).to contain_package('opensearch').
              with(ensure: 'absent')
          }
        else
          it {
            expect(subject).to contain_package('opensearch').
              with(ensure: 'purged')
          }
        end

        it {
          expect(subject).to contain_service('opensearch').
            with(
              ensure: 'stopped',
              enable: 'false'
            )
        }

        it {
          expect(subject).to contain_file('/usr/share/opensearch/plugins').
            with(ensure: 'absent')
        }

        it {
          expect(subject).to contain_file("#{defaults_path}/opensearch").
            with(ensure: 'absent')
        }
      end

      context 'When managing the repository' do
        let(:params) do
          default_params.merge(
            manage_repo: true
          )
        end

        it { is_expected.to contain_class('elastic_stack::repo') }
      end

      context 'When not managing the repository' do
        let(:params) do
          default_params.merge(
            manage_repo: false
          )
        end

        it { is_expected.to compile.with_all_deps }
      end
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers

  on_supported_os(
    hardwaremodels: ['x86_64'],
    supported_os: [
      {
        'operatingsystem' => 'CentOS',
        'operatingsystemrelease' => ['7']
      }
    ]
  ).each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts.merge(
          scenario: '',
          common: ''
        )
      end

      describe 'main class tests' do
        # init.pp
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('opensearch') }
        it { is_expected.to contain_class('opensearch::package') }

        it {
          expect(subject).to contain_class('opensearch::config').
            that_requires('Class[opensearch::package]')
        }

        it {
          expect(subject).to contain_class('opensearch::service').
            that_requires('Class[opensearch::config]')
        }

        # Base directories
        it { is_expected.to contain_file('/etc/opensearch') }
        it { is_expected.to contain_file('/usr/share/opensearch') }
        it { is_expected.to contain_file('/usr/share/opensearch/lib') }
        it { is_expected.to contain_file('/var/lib/opensearch') }

        it { is_expected.to contain_exec('remove_plugin_dir') }
      end

      context 'package installation' do
        describe 'with default package' do
          it {
            expect(subject).to contain_package('opensearch').
              with(ensure: 'present')
          }

          it {
            expect(subject).not_to contain_package('my-opensearch').
              with(ensure: 'present')
          }
        end

        describe 'with specified package name' do
          let(:params) do
            default_params.merge(
              package_name: 'my-opensearch'
            )
          end

          it {
            expect(subject).to contain_package('opensearch').
              with(ensure: 'present', name: 'my-opensearch')
          }

          it {
            expect(subject).not_to contain_package('opensearch').
              with(ensure: 'present', name: 'opensearch')
          }
        end

        describe 'with auto upgrade enabled' do
          let(:params) do
            default_params.merge(
              autoupgrade: true
            )
          end

          it {
            expect(subject).to contain_package('opensearch').
              with(ensure: 'latest')
          }
        end
      end

      describe 'running a a different user' do
        let(:params) do
          default_params.merge(
            opensearch_user: 'myesuser',
            opensearch_group: 'myesgroup'
          )
        end

        it {
          expect(subject).to contain_file('/etc/opensearch').
            with(owner: 'myesuser', group: 'myesgroup')
        }

        it {
          expect(subject).to contain_file('/var/log/opensearch').
            with(owner: 'myesuser')
        }

        it {
          expect(subject).to contain_file('/usr/share/opensearch').
            with(owner: 'myesuser', group: 'myesgroup')
        }

        it {
          expect(subject).to contain_file('/var/lib/opensearch').
            with(owner: 'myesuser', group: 'myesgroup')
        }
      end

      describe 'setting jvm_options before version 7.7.0' do
        jvm_options = [
          '-Xms16g',
          '-Xmx16g'
        ]

        let(:params) do
          default_params.merge(
            jvm_options: jvm_options,
            version: '7.0.0'
          )
        end

        jvm_options.each do |jvm_option|
          it {
            expect(subject).to contain_file_line("jvm_option_#{jvm_option}").
              with(
                ensure: 'present',
                path: '/etc/opensearch/jvm.options',
                line: jvm_option
              )
          }
        end
      end

      describe 'setting jvm_options after version 7.7.0' do
        jvm_options = [
          '-Xms16g',
          '-Xmx16g'
        ]

        let(:params) do
          default_params.merge(
            jvm_options: jvm_options,
            version: '7.7.0'
          )
        end

        it {
          expect(subject).to contain_file('/etc/opensearch/jvm.options.d/jvm.options').
            with(ensure: 'file')
        }
      end

      context 'with restart_on_change => true' do
        let(:params) do
          default_params.merge(
            restart_on_change: true
          )
        end

        describe 'should restart opensearch' do
          it {
            expect(subject).to contain_file('/etc/opensearch/opensearch.yml').
              that_notifies('Service[opensearch]')
          }
        end

        describe 'setting jvm_options triggers restart before version 7.7.0' do
          let(:params) do
            super().merge(
              jvm_options: ['-Xmx16g'],
              version: '7.0.0'
            )
          end

          it {
            expect(subject).to contain_file_line('jvm_option_-Xmx16g').
              that_notifies('Service[opensearch]')
          }
        end

        describe 'setting jvm_options triggers restart after version 7.7.0' do
          let(:params) do
            super().merge(
              jvm_options: ['-Xmx16g'],
              version: '7.7.0'
            )
          end

          it {
            expect(subject).to contain_file('/etc/opensearch/jvm.options.d/jvm.options').
              that_notifies('Service[opensearch]')
          }
        end
      end

      # This check helps catch dependency cycles.
      context 'create_resource' do
        # Helper for these tests
        def singular(string)
          case string
          when 'indices'
            'index'
          when 'snapshot_repositories'
            'snapshot_repository'
          else
            string[0..-2]
          end
        end

        {
          'indices' => { 'test-index' => {} },
          # 'instances' => { 'es-instance' => {} },
          'pipelines' => { 'testpipeline' => { 'content' => {} } },
          'plugins' => { 'head' => {} },
          'roles' => { 'elastic_role' => {} },
          'scripts' => {
            'foo' => { 'source' => 'puppet:///path/to/foo.groovy' }
          },
          'snapshot_repositories' => { 'backup' => { 'location' => '/backups' } },
          'templates' => { 'foo' => { 'content' => {} } },
          'users' => { 'elastic' => { 'password' => 'foobar' } }
        }.each_pair do |deftype, params|
          describe deftype do
            let(:params) do
              default_params.merge(
                deftype => params
              )
            end

            it { is_expected.to compile }

            it {
              expect(subject).to send(
                "contain_opensearch__#{singular(deftype)}", params.keys.first
              )
            }
          end
        end
      end

      describe 'oss' do
        let(:params) do
          default_params.merge(oss: true)
        end

        it do
          expect(subject).to contain_package('opensearch').with(
            name: 'opensearch-oss'
          )
        end
      end
    end
  end
end
