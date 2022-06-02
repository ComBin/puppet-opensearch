# frozen_string_literal: true

require 'spec_helper'

describe 'opensearch', type: 'class' do
  default_params = {
    config: { 'node.name' => 'foo' }
  }

  let(:params) do
    default_params.merge({})
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
      context 'hiera' do
        describe 'indices' do
          context 'single indices' do
            let(:facts) { facts.merge(scenario: 'singleindex') }

            it {
              expect(subject).to contain_opensearch__index('baz').
                with(
                  ensure: 'present',
                  settings: {
                    'index' => {
                      'number_of_shards' => 1
                    }
                  }
                )
            }

            it { is_expected.to contain_opensearch_index('baz') }

            it {
              expect(subject).to contain_es_instance_conn_validator(
                'baz-index-conn-validator'
              )
            }
          end

          context 'no indices' do
            let(:facts) { facts.merge(scenario: '') }

            it { is_expected.not_to contain_opensearch__index('baz') }
          end
        end

        context 'config' do
          let(:facts) { facts.merge(scenario: 'singleinstance') }

          it { is_expected.to contain_augeas('/etc/sysconfig/opensearch') }
          it { is_expected.to contain_file('/etc/opensearch/opensearch.yml') }
          it { is_expected.to contain_datacat('/etc/opensearch/opensearch.yml') }
          it { is_expected.to contain_datacat_fragment('main_config') }

          it {
            expect(subject).to contain_service('opensearch').with(
              ensure: 'running',
              enable: true
            )
          }
        end

        describe 'pipelines' do
          context 'single pipeline' do
            let(:facts) { facts.merge(scenario: 'singlepipeline') }

            it {
              expect(subject).to contain_opensearch__pipeline('testpipeline').
                with(
                  ensure: 'present',
                  content: {
                    'description' => 'Add the foo field',
                    'processors' => [
                      {
                        'set' => {
                          'field' => 'foo',
                          'value' => 'bar'
                        }
                      }
                    ]
                  }
                )
            }

            it { is_expected.to contain_opensearch_pipeline('testpipeline') }
          end

          context 'no pipelines' do
            let(:facts) { facts.merge(scenario: '') }

            it { is_expected.not_to contain_opensearch__pipeline('testpipeline') }
          end
        end

        describe 'plugins' do
          context 'single plugin' do
            let(:facts) { facts.merge(scenario: 'singleplugin') }

            it {
              expect(subject).to contain_opensearch__plugin('mobz/opensearch-head').
                with(
                  ensure: 'present',
                  module_dir: 'head'
                )
            }

            it { is_expected.to contain_opensearch_plugin('mobz/opensearch-head') }
          end

          context 'no plugins' do
            let(:facts) { facts.merge(scenario: '') }

            it {
              expect(subject).not_to contain_opensearch__plugin(
                'mobz/opensearch-head/1.0.0'
              )
            }
          end
        end

        describe 'roles' do
          context 'single roles' do
            let(:facts) { facts.merge(scenario: 'singlerole') }
            let(:params) do
              default_params
            end

            it {
              expect(subject).to contain_opensearch__role('admin').
                with(
                  ensure: 'present',
                  privileges: {
                    'cluster' => 'monitor',
                    'indices' => {
                      '*' => 'all'
                    }
                  },
                  mappings: [
                    'cn=users,dc=example,dc=com'
                  ]
                )
            }

            it { is_expected.to contain_opensearch_role('admin') }
            it { is_expected.to contain_opensearch_role_mapping('admin') }
          end

          context 'no roles' do
            let(:facts) { facts.merge(scenario: '') }

            it { is_expected.not_to contain_opensearch__role('admin') }
          end
        end

        describe 'scripts' do
          context 'single scripts' do
            let(:facts) { facts.merge(scenario: 'singlescript') }

            it {
              expect(subject).to contain_opensearch__script('myscript').
                with(
                  ensure: 'present',
                  source: 'puppet:///file/here'
                )
            }

            it { is_expected.to contain_file('/usr/share/opensearch/scripts/here') }
          end

          context 'no roles' do
            let(:facts) { facts.merge(scenario: '') }

            it { is_expected.not_to contain_opensearch__script('myscript') }
          end
        end

        describe 'templates' do
          context 'single template' do
            let(:facts) { facts.merge(scenario: 'singletemplate') }

            it {
              expect(subject).to contain_opensearch__template('foo').
                with(
                  ensure: 'present',
                  content: {
                    'template' => 'foo-*',
                    'settings' => {
                      'index' => {
                        'number_of_replicas' => 0
                      }
                    }
                  }
                )
            }

            it { is_expected.to contain_opensearch_template('foo') }
          end

          context 'no templates' do
            let(:facts) { facts.merge(scenario: '') }

            it { is_expected.not_to contain_opensearch__template('foo') }
          end
        end

        describe 'users' do
          context 'single users' do
            let(:facts) { facts.merge(scenario: 'singleuser') }
            let(:params) do
              default_params
            end

            it {
              expect(subject).to contain_opensearch__user('elastic').
                with(
                  ensure: 'present',
                  roles: ['admin'],
                  password: 'password'
                )
            }

            it { is_expected.to contain_opensearch_user('elastic') }
          end

          context 'no users' do
            let(:facts) { facts.merge(scenario: '') }

            it { is_expected.not_to contain_opensearch__user('elastic') }
          end
        end
      end
    end
  end
end
