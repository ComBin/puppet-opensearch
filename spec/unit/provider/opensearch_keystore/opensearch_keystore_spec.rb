# frozen_string_literal: true

require 'spec_helper_rspec'

shared_examples 'keystore instance' do |instance|
  describe "instance #{instance}" do
    subject { described_class.instances.find { |x| x.name == instance } }

    it { expect(subject).to be_exists }
    it { expect(subject.name).to eq(instance) }

    it {
      expect(subject.settings).
        to eq(['node.name', 'cloud.aws.access_key'])
    }
  end
end

describe Puppet::Type.type(:opensearch_keystore).provider(:opensearch_keystore) do
  let(:executable) { '/usr/share/opensearch/bin/opensearch-keystore' }
  let(:instances) { [] }

  before do
    Facter.clear
    Facter.add('osfamily') { setcode { 'Debian' } }

    allow(described_class).
      to receive(:command).
      with(:keystore).
      and_return(executable)

    allow(File).to receive(:exist?).
      with('/etc/opensearch/scripts/opensearch.keystore').
      and_return(false)
  end

  describe 'instances' do
    before do
      allow(Dir).to receive(:[]).
        with('/etc/opensearch/*').
        and_return((['scripts'] + instances).map do |directory|
          "/etc/opensearch/#{directory}"
        end)

      instances.each do |instance|
        instance_dir = "/etc/opensearch/#{instance}"
        defaults_file = "/etc/default/opensearch-#{instance}"

        allow(File).to receive(:exist?).
          with("#{instance_dir}/opensearch.keystore").
          and_return(true)

        allow(described_class).
          to receive(:execute).
          with(
            [executable, 'list'],
            custom_environment: {
              'ES_INCLUDE' => defaults_file,
              'ES_PATH_CONF' => "/etc/opensearch/#{instance}"
            },
            uid: 'opensearch',
            gid: 'opensearch',
            failonfail: true
          ).
          and_return(
            Puppet::Util::Execution::ProcessOutput.new(
              "node.name\ncloud.aws.access_key\n", 0
            )
          )
      end
    end

    it 'has an instance method' do
      expect(described_class).to respond_to(:instances)
    end

    context 'without any keystores' do
      it 'returns no resources' do
        expect(described_class.instances.size).to eq(0)
      end
    end

    context 'with one instance' do
      let(:instances) { ['es-01'] }

      it { expect(described_class.instances.length).to eq(instances.length) }

      include_examples 'keystore instance', 'es-01'
    end

    context 'with multiple instances' do
      let(:instances) { %w[es-01 es-02] }

      it { expect(described_class.instances.length).to eq(instances.length) }

      include_examples 'keystore instance', 'es-01'
      include_examples 'keystore instance', 'es-02'
    end
  end

  describe 'prefetch' do
    it 'has a prefetch method' do
      expect(described_class).to respond_to :prefetch
    end
  end

  describe 'flush' do
    let(:provider) { described_class.new(name: 'es-03') }
    let(:resource) do
      Puppet::Type.type(:opensearch_keystore).new(
        name: 'es-03',
        provider: provider
      )
    end

    it 'creates the keystore' do
      allow(described_class).to(
        receive(:execute).
          with(
            [executable, 'create'],
            custom_environment: {
              'ES_INCLUDE' => '/etc/default/opensearch-es-03',
              'ES_PATH_CONF' => '/etc/opensearch/es-03'
            },
            uid: 'opensearch',
            gid: 'opensearch',
            failonfail: true
          ).
          and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
      )
      resource[:ensure] = :present
      provider.create
      provider.flush
      expect(described_class).to(
        have_received(:execute).
          with(
            [executable, 'create'],
            custom_environment: {
              'ES_INCLUDE' => '/etc/default/opensearch-es-03',
              'ES_PATH_CONF' => '/etc/opensearch/es-03'
            },
            uid: 'opensearch',
            gid: 'opensearch',
            failonfail: true
          )
      )
    end

    it 'deletes the keystore' do
      allow(File).to(
        receive(:delete).
          with(File.join(%w[/ etc opensearch es-03 opensearch.keystore]))
      )
      resource[:ensure] = :absent
      provider.destroy
      provider.flush
      expect(File).to(
        have_received(:delete).
          with(File.join(%w[/ etc opensearch es-03 opensearch.keystore]))
      )
    end

    it 'updates settings' do
      settings = {
        'cloud.aws.access_key' => 'AKIAFOOBARFOOBAR',
        'cloud.aws.secret_key' => 'AKIAFOOBARFOOBAR'
      }

      settings.each do |setting, value|
        allow(provider.class).to(
          receive(:run_keystore).
            with(['add', '--force', '--stdin', setting], 'es-03', '/etc/opensearch', value).
            and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
        )
      end

      # Note that the settings hash is passed in wrapped in an array to mimic
      # the  behavior in real-world puppet runs.
      resource[:ensure] = :present
      resource[:settings] = [settings]
      provider.settings = [settings]
      provider.flush

      settings.each do |setting, value|
        expect(provider.class).to(
          have_received(:run_keystore).
            with(['add', '--force', '--stdin', setting], 'es-03', '/etc/opensearch', value)
        )
      end
    end
  end
end
