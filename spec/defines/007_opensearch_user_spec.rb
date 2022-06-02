# frozen_string_literal: true

require 'spec_helper'
require 'helpers/class_shared_examples'

describe 'opensearch::user' do
  let(:title) { 'elastic' }

  let(:pre_condition) do
    <<-EOS
      class { 'opensearch': }
    EOS
  end

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

      context 'with default parameters' do
        let(:params) do
          {
            password: 'foobar',
            roles: %w[monitor user]
          }
        end

        it { is_expected.to contain_opensearch__user('elastic') }
        it { is_expected.to contain_opensearch_user('elastic') }

        it do
          expect(subject).to contain_opensearch_user_roles('elastic').with(
            'ensure' => 'present',
            'roles' => %w[monitor user]
          )
        end
      end

      describe 'collector ordering' do
        let(:pre_condition) do
          <<-EOS
            class { 'opensearch': }
            opensearch::template { 'foo': content => {"foo" => "bar"} }
            opensearch::role { 'test_role':
              privileges => {
                'cluster' => 'monitor',
                'indices' => {
                  '*' => 'all',
                },
              },
            }
          EOS
        end

        let(:params) do
          {
            password: 'foobar',
            roles: %w[monitor user]
          }
        end

        it { is_expected.to contain_opensearch__role('test_role') }
        it { is_expected.to contain_opensearch_role('test_role') }
        it { is_expected.to contain_opensearch_role_mapping('test_role') }

        it {
          expect(subject).to contain_opensearch__user('elastic').
            that_comes_before([
                                'Opensearch::Template[foo]'
                              ]).that_requires([
                                                 'Opensearch::Role[test_role]'
                                               ])
        }

        include_examples 'class', :systemd
      end
    end
  end
end
