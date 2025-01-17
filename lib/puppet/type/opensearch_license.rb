# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))

require 'puppet_x/elastic/asymmetric_compare'
require 'puppet_x/elastic/deep_to_i'
require 'puppet_x/elastic/deep_to_s'
require 'puppet_x/elastic/opensearch_rest_resource'

Puppet::Type.newtype(:opensearch_license) do
  extend OpensearchRESTResource

  desc 'Manages Opensearch licenses.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'Pipeline name.'
  end

  newproperty(:content) do
    desc 'Structured hash for license content data.'

    def insync?(value)
      Puppet_X::Elastic.asymmetric_compare(
        should.transform_values { |v| v.is_a?(Hash) ? (v.reject { |s, _| s == 'signature' }) : v },
        value
      )
    end

    def should_to_s(newvalue)
      newvalue.transform_values do |license_data|
        if license_data.is_a? Hash
          license_data.map do |field, value|
            [field, field == 'signature' ? '[redacted]' : value]
          end.to_h
        else
          v
        end
      end.to_s
    end

    validate do |value|
      raise Puppet::Error, 'hash expected' unless value.is_a? Hash
    end

    munge do |value|
      Puppet_X::Elastic.deep_to_i(Puppet_X::Elastic.deep_to_s(value))
    end
  end
end
