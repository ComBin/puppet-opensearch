# frozen_string_literal: true

require_relative 'shared_examples'

provider_class = Puppet::Type.type(:opensearch_plugin).provider(:opensearch_plugin)

describe provider_class do
  let(:resource_name) { 'lmenezes/opensearch-kopf' }
  let(:resource) do
    Puppet::Type.type(:opensearch_plugin).new(
      name: resource_name,
      ensure: :present,
      provider: 'opensearch_plugin'
    )
  end
  let(:provider) do
    provider = provider_class.new
    provider.resource = resource
    provider
  end
  let(:shortname) { provider.plugin_name(resource_name) }
  let(:klass) { provider_class }

  include_examples 'plugin provider', '7.0.0'
end
