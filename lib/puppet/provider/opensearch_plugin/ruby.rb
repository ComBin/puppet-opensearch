# frozen_string_literal: true

require 'puppet/provider/elastic_plugin'

Puppet::Type.type(:opensearch_plugin).provide(
  :opensearch_plugin,
  parent: Puppet::Provider::ElasticPlugin
) do
  desc <<-END
    Post-5.x provider for Opensearch bin/opensearch-plugin
    command operations.'
  END

  case Facter.value('osfamily')
  when 'OpenBSD'
    commands plugin: '/usr/local/opensearch/bin/opensearch-plugin'
    commands es: '/usr/local/opensearch/bin/opensearch'
    commands javapathhelper: '/usr/local/bin/javaPathHelper'
  else
    commands plugin: '/usr/share/opensearch/bin/opensearch-plugin'
    commands es: '/usr/share/opensearch/bin/opensearch'
  end
end
