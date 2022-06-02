# frozen_string_literal: true

require 'spec_helper'

describe 'plugin_dir' do
  describe 'exception handling' do
    describe 'with no arguments' do
      it {
        expect(subject).to run.with_params.
          and_raise_error(Puppet::ParseError)
      }
    end

    describe 'more than two arguments' do
      it {
        expect(subject).to run.with_params('a', 'b', 'c').
          and_raise_error(Puppet::ParseError)
      }
    end

    describe 'non-string arguments' do
      it {
        expect(subject).to run.with_params([]).
          and_raise_error(Puppet::ParseError)
      }
    end
  end

  {
    'mobz/opensearch-head' => 'head',
    'lukas-vlcek/bigdesk/2.4.0' => 'bigdesk',
    'opensearch/opensearch-cloud-aws/2.5.1' => 'cloud-aws',
    'com.sksamuel.opensearch/opensearch-river-redis/1.1.0' => 'river-redis',
    'com.github.lbroudoux.opensearch/amazon-s3-river/1.4.0' => 'amazon-s3-river',
    'opensearch/opensearch-lang-groovy/2.0.0' => 'lang-groovy',
    'royrusso/opensearch-hq' => 'hq',
    'polyfractal/opensearch-inquisitor' => 'inquisitor',
    'mycustomplugin' => 'mycustomplugin'
  }.each do |plugin, dir|
    describe "parsed dir for #{plugin}" do
      it { is_expected.to run.with_params(plugin).and_return(dir) }
    end
  end
end
