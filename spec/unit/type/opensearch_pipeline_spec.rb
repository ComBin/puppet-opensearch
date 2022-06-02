# frozen_string_literal: true

require_relative '../../helpers/unit/type/opensearch_rest_shared_examples'

describe Puppet::Type.type(:opensearch_pipeline) do
  let(:resource_name) { 'test_pipeline' }

  include_examples 'REST API types', 'pipeline', :content
end
