# frozen_string_literal: true

require 'spec_helper'
require 'helpers/class_shared_examples'

describe 'opensearch::role' do
  let(:title) { 'elastic_role' }

  let(:pre_condition) do
    <<-EOS
      class { 'opensearch': }
    EOS
  end

  let(:params) do
    {
      privileges: {
        'cluster' => '*'
      },
      mappings: [
        'cn=users,dc=example,dc=com',
        'cn=admins,dc=example,dc=com',
        'cn=John Doe,cn=other users,dc=example,dc=com'
      ]
    }
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

      context 'with an invalid role name' do
        context 'too long' do
          let(:title) { 'A' * 41 }

          it { is_expected.to raise_error(Puppet::Error, %r{expected length}i) }
        end
      end

      context 'with default parameters' do
        it { is_expected.to contain_opensearch__role('elastic_role') }
        it { is_expected.to contain_opensearch_role('elastic_role') }

        it do
          expect(subject).to contain_opensearch_role_mapping('elastic_role').with(
            'ensure' => 'present',
            'mappings' => [
              'cn=users,dc=example,dc=com',
              'cn=admins,dc=example,dc=com',
              'cn=John Doe,cn=other users,dc=example,dc=com'
            ]
          )
        end
      end

      describe 'collector ordering' do
        describe 'when present' do
          let(:pre_condition) do
            <<-EOS
              class { 'opensearch': }
              opensearch::template { 'foo': content => {"foo" => "bar"} }
              opensearch::user { 'elastic':
                password => 'foobar',
                roles => ['elastic_role'],
              }
            EOS
          end

          it {
            expect(subject).to contain_opensearch__role('elastic_role').
              that_comes_before([
                                  'Opensearch::Template[foo]',
                                  'Opensearch::User[elastic]'
                                ])
          }

          include_examples 'class', :systemd
        end

        describe 'when absent' do
          let(:pre_condition) do
            <<-EOS
              class { 'opensearch': }
              opensearch::template { 'foo': content => {"foo" => "bar"} }
              opensearch::user { 'elastic':
                password => 'foobar',
                roles => ['elastic_role'],
              }
            EOS
          end

          include_examples 'class', :systemd
          # TODO: Uncomment once upstream issue is fixed.
          # https://github.com/rodjek/rspec-puppet/issues/418
          # it { should contain_opensearch__shield__role('elastic_role')
          #   .that_comes_before([
          #   'Opensearch::Template[foo]',
          #   'Opensearch::Plugin[shield]',
          #   'Opensearch::Shield::User[elastic]'
          # ])}
        end
      end
    end
  end
end
