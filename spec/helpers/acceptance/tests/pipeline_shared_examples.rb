# frozen_string_literal: true

require 'json'
require 'helpers/acceptance/tests/manifest_shared_examples'
require 'helpers/acceptance/tests/bad_manifest_shared_examples'

shared_examples 'pipeline operations' do |es_config, pipeline|
  describe 'pipeline resources' do
    let(:pipeline_name) { 'foo' }

    context 'present' do
      let(:extra_manifest) do
        <<-MANIFEST
          opensearch::pipeline { '#{pipeline_name}':
            ensure  => 'present',
            content => #{pipeline}
          }
        MANIFEST
      end

      include_examples('manifest application')

      include_examples('pipeline content', es_config, pipeline)
    end

    context 'absent' do
      let(:extra_manifest) do
        <<-MANIFEST
          opensearch::template { '#{pipeline_name}':
            ensure => absent,
          }
        MANIFEST
      end

      include_examples('manifest application')
    end
  end
end

# Verifies the content of a loaded index template.
shared_examples 'pipeline content' do |es_config, pipeline|
  opensearch_port = es_config['http.port']
  describe port(opensearch_port) do
    it 'open', :with_retries do
      expect(subject).to be_listening
    end
  end

  describe "http://localhost:#{opensearch_port}/_ingest/pipeline" do
    subject { shell("curl http://localhost:#{opensearch_port}/_ingest/pipeline") }

    it 'returns the configured pipelines', :with_retries do
      expect(JSON.parse(subject.stdout).values).
        to include(include(pipeline))
    end
  end
end
