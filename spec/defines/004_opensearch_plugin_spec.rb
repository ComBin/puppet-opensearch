# frozen_string_literal: true

require 'spec_helper'
require 'helpers/class_shared_examples'

describe 'opensearch::plugin', type: 'define' do
  let(:title) { 'mobz/opensearch-head/1.0.0' }

  on_supported_os(
    hardwaremodels: ['x86_64'],
    supported_os: [
      {
        'operatingsystem' => 'CentOS',
        'operatingsystemrelease' => ['6']
      }
    ]
  ).each do |_os, facts|
    let(:facts) do
      facts.merge('scenario' => '', 'common' => '')
    end

    let(:pre_condition) do
      <<-EOS
        class { "opensearch":
          config => {
            "node" => {
              "name" => "test"
            }
          }
        }
      EOS
    end

    context 'default values' do
      context 'present' do
        let(:params) do
          {
            ensure: 'present',
            configdir: '/etc/opensearch'
          }
        end

        it { is_expected.to compile }
      end

      context 'absent' do
        let(:params) do
          {
            ensure: 'absent'
          }
        end

        it { is_expected.to compile }
      end

      context 'configdir' do
        it {
          expect(subject).to contain_opensearch__plugin(
            'mobz/opensearch-head/1.0.0'
          ).with_configdir('/etc/opensearch')
        }

        it {
          expect(subject).to contain_opensearch_plugin(
            'mobz/opensearch-head/1.0.0'
          ).with_configdir('/etc/opensearch')
        }
      end
    end

    context 'with module_dir' do
      context 'add a plugin' do
        let(:params) do
          {
            ensure: 'present',
            module_dir: 'head'
          }
        end

        it {
          expect(subject).to contain_opensearch__plugin(
            'mobz/opensearch-head/1.0.0'
          )
        }

        it {
          expect(subject).to contain_opensearch_plugin(
            'mobz/opensearch-head/1.0.0'
          )
        }

        it {
          expect(subject).to contain_file(
            '/usr/share/opensearch/plugins/head'
          ).that_requires(
            'Opensearch_plugin[mobz/opensearch-head/1.0.0]'
          )
        }
      end

      context 'remove a plugin' do
        let(:params) do
          {
            ensure: 'absent',
            module_dir: 'head'
          }
        end

        it {
          expect(subject).to contain_opensearch__plugin(
            'mobz/opensearch-head/1.0.0'
          )
        }

        it {
          expect(subject).to contain_opensearch_plugin(
            'mobz/opensearch-head/1.0.0'
          ).with(
            ensure: 'absent'
          )
        }

        it {
          expect(subject).to contain_file(
            '/usr/share/opensearch/plugins/head'
          ).that_requires(
            'Opensearch_plugin[mobz/opensearch-head/1.0.0]'
          )
        }
      end
    end

    context 'with url' do
      context 'add a plugin with full name' do
        let(:params) do
          {
            ensure: 'present',
            url: 'https://github.com/mobz/opensearch-head/archive/master.zip'
          }
        end

        it { is_expected.to contain_opensearch__plugin('mobz/opensearch-head/1.0.0') }
        it { is_expected.to contain_opensearch_plugin('mobz/opensearch-head/1.0.0').with(ensure: 'present', url: 'https://github.com/mobz/opensearch-head/archive/master.zip') }
      end
    end

    context 'offline plugin install' do
      let(:title) { 'head' }
      let(:params) do
        {
          ensure: 'present',
          source: 'puppet:///path/to/my/plugin.zip'
        }
      end

      it { is_expected.to contain_opensearch__plugin('head') }
      it { is_expected.to contain_file('/opt/opensearch/swdl/plugin.zip').with(source: 'puppet:///path/to/my/plugin.zip', before: 'Opensearch_plugin[head]') }
      it { is_expected.to contain_opensearch_plugin('head').with(ensure: 'present', source: '/opt/opensearch/swdl/plugin.zip') }
    end

    describe 'service restarts' do
      let(:title) { 'head' }
      let(:params) do
        {
          ensure: 'present',
          module_dir: 'head'
        }
      end

      context 'restart_on_change set to false (default)' do
        let(:pre_condition) do
          <<-EOS
            class { "opensearch": }
          EOS
        end

        it {
          expect(subject).not_to contain_opensearch_plugin(
            'head'
          ).that_notifies(
            'Service[opensearch]'
          )
        }

        include_examples 'class', :sysv
      end

      context 'restart_on_change set to true' do
        let(:pre_condition) do
          <<-EOS
            class { "opensearch":
              restart_on_change => true,
            }
          EOS
        end

        it {
          expect(subject).to contain_opensearch_plugin(
            'head'
          ).that_notifies(
            'Service[opensearch]'
          )
        }

        include_examples('class')
      end

      context 'restart_plugin_change set to false (default)' do
        let(:pre_condition) do
          <<-EOS
            class { "opensearch":
              restart_plugin_change => false,
            }
          EOS
        end

        it {
          expect(subject).not_to contain_opensearch_plugin(
            'head'
          ).that_notifies(
            'Service[opensearch]'
          )
        }

        include_examples('class')
      end

      context 'restart_plugin_change set to true' do
        let(:pre_condition) do
          <<-EOS
            class { "opensearch":
              restart_plugin_change => true,
            }
          EOS
        end

        it {
          expect(subject).to contain_opensearch_plugin(
            'head'
          ).that_notifies(
            'Service[opensearch]'
          )
        }

        include_examples('class')
      end
    end

    describe 'proxy arguments' do
      let(:title) { 'head' }

      context 'unauthenticated' do
        context 'on define' do
          let(:params) do
            {
              ensure: 'present',
              proxy_host: 'es.local',
              proxy_port: 8080
            }
          end

          it {
            expect(subject).to contain_opensearch_plugin(
              'head'
            ).with_proxy(
              'http://es.local:8080'
            )
          }
        end

        context 'on main class' do
          let(:params) do
            {
              ensure: 'present'
            }
          end

          let(:pre_condition) do
            <<-EOS
              class { 'opensearch':
                proxy_url => 'https://es.local:8080',
              }
            EOS
          end

          it {
            expect(subject).to contain_opensearch_plugin(
              'head'
            ).with_proxy(
              'https://es.local:8080'
            )
          }
        end
      end

      context 'authenticated' do
        context 'on define' do
          let(:params) do
            {
              ensure: 'present',
              proxy_host: 'es.local',
              proxy_port: 8080,
              proxy_username: 'elastic',
              proxy_password: 'password'
            }
          end

          it {
            expect(subject).to contain_opensearch_plugin(
              'head'
            ).with_proxy(
              'http://elastic:password@es.local:8080'
            )
          }
        end

        context 'on main class' do
          let(:params) do
            {
              ensure: 'present'
            }
          end

          let(:pre_condition) do
            <<-EOS
              class { 'opensearch':
                proxy_url => 'http://elastic:password@es.local:8080',
              }
            EOS
          end

          it {
            expect(subject).to contain_opensearch_plugin(
              'head'
            ).with_proxy(
              'http://elastic:password@es.local:8080'
            )
          }
        end
      end
    end

    describe 'collector ordering' do
      describe 'present' do
        let(:title) { 'head' }
        let(:pre_condition) do
          <<-EOS
            class { 'opensearch': }
          EOS
        end

        it {
          expect(subject).to contain_opensearch__plugin(
            'head'
          ).that_requires(
            'Class[opensearch::config]'
          )
        }

        it {
          expect(subject).to contain_opensearch_plugin(
            'head'
          ).that_comes_before(
            'Service[opensearch]'
          )
        }

        include_examples 'class'
      end
    end
  end
end
