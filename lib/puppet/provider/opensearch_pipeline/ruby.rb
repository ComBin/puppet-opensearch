# frozen_string_literal: true

require 'puppet/provider/elastic_rest'

Puppet::Type.type(:opensearch_pipeline).provide(
  :ruby,
  parent: Puppet::Provider::ElasticREST,
  metadata: :content,
  api_uri: '_ingest/pipeline'
) do
  desc 'A REST API based provider to manage Opensearch ingest pipelines.'

  mk_resource_methods
end
