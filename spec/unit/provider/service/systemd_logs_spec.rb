#! /usr/bin/env ruby
#
# Unit testing for the systemd service Provider
#
require 'spec_helper'

describe Puppet::Type.type(:service).provider(:systemd_logs) do
  before :each do
    described_class.stubs(:which).with('systemctl').returns '/bin/systemctl'
  end

  let :provider do
    described_class.new(:name => 'sshd.service')
  end

  [:enabled?, :enable, :disable, :start, :stop, :status, :restart].each do |method|
    it "should have a #{method} method" do
      expect(provider).to respond_to(method)
    end
  end

  describe "#start" do
    it "should use the supplied start command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :start => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.start
    end

    it "should start the service with systemctl start otherwise" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:systemctl).with(:unmask, 'sshd.service')
      provider.expects(:execute).with(['/bin/systemctl','start','sshd.service'], {:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
      provider.start
    end

    it "should show journald logs on failure" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:systemctl).with(:unmask, 'sshd.service')
      provider.expects(:execute).with(['/bin/systemctl','start','sshd.service'],{:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
        .raises(Puppet::ExecutionFailure, "Failed to start sshd.service: Unit sshd.service failed to load: Invalid argument. See system logs and 'systemctl status sshd.service' for details.")
      journalctl_logs = <<-EOS
      -- Logs begin at Tue 2016-06-14 11:59:21 UTC, end at Tue 2016-06-14 21:45:02 UTC. --
Jun 14 21:41:34 foo.example.com systemd[1]: Stopping sshd Service...
Jun 14 21:41:35 foo.example.com systemd[1]: Starting sshd Service...
Jun 14 21:43:23 foo.example.com systemd[1]: sshd.service lacks both ExecStart= and ExecStop= setting. Refusing.
      EOS
      provider.expects(:execute).with("journalctl -n 50 --since '5 minutes ago' -u sshd.service --no-pager").returns(journalctl_logs)
      expect { provider.start }.to raise_error(Puppet::Error, /Systemd start for sshd.service failed:journalctl log for sshd.service:       -- Logs begin at Tue 2016-06-14 11:59:21 UTC, end at Tue 2016-06-14 21:45:02 UTC. --/)
    end
  end

  describe "#stop" do
    it "should use the supplied stop command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :stop => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.stop
    end

    it "should stop the service with systemctl stop otherwise" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:execute).with(['/bin/systemctl','stop','sshd.service'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.stop
    end

    it "should show journald logs on failure" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:execute).with(['/bin/systemctl','stop','sshd.service'],{:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
        .raises(Puppet::ExecutionFailure, "Failed to stop sshd.service: Unit sshd.service failed to load: Invalid argument. See system logs and 'systemctl status sshd.service' for details.")
      journalctl_logs = <<-EOS
      -- Logs begin at Tue 2016-06-14 11:59:21 UTC, end at Tue 2016-06-14 21:45:02 UTC. --
Jun 14 21:41:34 foo.example.com systemd[1]: Stopping sshd Service...
Jun 14 21:41:35 foo.example.com systemd[1]: Starting sshd Service...
Jun 14 21:43:23 foo.example.com systemd[1]: sshd.service lacks both ExecStart= and ExecStop= setting. Refusing.
      EOS
      provider.expects(:execute).with("journalctl -n 50 --since '5 minutes ago' -u sshd.service --no-pager").returns(journalctl_logs)
      expect { provider.stop }.to raise_error(Puppet::Error, /Systemd stop for sshd.service failed:journalctl log for sshd.service:       -- Logs begin at Tue 2016-06-14 11:59:21 UTC, end at Tue 2016-06-14 21:45:02 UTC. --/)
    end
  end

  describe "#enabled?" do
    it "should return :true if the service is enabled" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:execute).with(['/bin/systemctl','is-enabled','sshd.service'], :failonfail => false).returns "enabled\n"
      $CHILD_STATUS.stubs(:exitstatus).returns(0)
      expect(provider.enabled?).to eq(:true)
    end

    it "should return :true if the service is static" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:execute).with(['/bin/systemctl','is-enabled','sshd.service'], :failonfail => false).returns "static\n"
      $CHILD_STATUS.stubs(:exitstatus).returns(0)
      expect(provider.enabled?).to eq(:true)
    end

    it "should return :false if the service is disabled" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:execute).with(['/bin/systemctl','is-enabled','sshd.service'], :failonfail => false).returns "disabled\n"
      expect(provider.enabled?).to eq(:false)
    end

    it "should return :false if the service is masked and the resource is attempting to be disabled" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :enable => false))
      provider.expects(:execute).with(['/bin/systemctl','is-enabled','sshd.service'], :failonfail => false).returns "masked\n"
      expect(provider.enabled?).to eq(:false)
    end

    it "should return :mask if the service is masked and the resource is attempting to be masked" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :enable => 'mask'))
      provider.expects(:execute).with(['/bin/systemctl','is-enabled','sshd.service'], :failonfail => false).returns "masked\n"
      expect(provider.enabled?).to eq(:mask)
    end
  end

  describe "#enable" do
    it "should run systemctl enable to enable a service" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:systemctl).with(:unmask, 'sshd.service')
      provider.expects(:systemctl).with(:enable, 'sshd.service')
      provider.enable
    end
  end

  describe "#disable" do
    it "should run systemctl disable to disable a service" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:systemctl).with(:disable, 'sshd.service')
      provider.disable
    end
  end

  describe "#mask" do
    it "should run systemctl to disable and mask a service" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      # :disable is the only call in the provider that uses a symbol instead of
      # a string.
      # This should be made consistent in the future and all tests updated.
      provider.expects(:systemctl).with(:disable, 'sshd.service')
      provider.expects(:systemctl).with(:mask, 'sshd.service')
      provider.mask
    end
  end

  # Note: systemd provider does not care about hasstatus or a custom status
  # command. I just assume that it does not make sense for systemd.
  describe "#status" do
    it "should return running if if the command returns 0" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:execute).with(['/bin/systemctl','is-active','sshd.service'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).returns "active\n"
      $CHILD_STATUS.stubs(:exitstatus).returns(0)
      expect(provider.status).to eq(:running)
    end

    [-10,-1,3,10].each { |ec|
      it "should return stopped if the command returns something non-0" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
        provider.expects(:execute).with(['/bin/systemctl','is-active','sshd.service'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).returns "inactive\n"
        $CHILD_STATUS.stubs(:exitstatus).returns(ec)
        expect(provider.status).to eq(:stopped)
      end
    }

    it "should use the supplied status command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :status => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
      provider.status
    end
  end

  # Note: systemd provider does not care about hasrestart. I just assume it
  # does not make sense for systemd
  describe "#restart" do
    it "should use the supplied restart command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :restart => '/bin/foo'))
      provider.expects(:execute).with(['/bin/systemctl','restart','sshd.service'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true).never
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end

    it "should restart the service with systemctl restart" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:execute).with(['/bin/systemctl','restart','sshd.service'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end

    it "should show journald logs on failure" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:execute).with(['/bin/systemctl','restart','sshd.service'],{:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
        .raises(Puppet::ExecutionFailure, "Failed to restart sshd.service: Unit sshd.service failed to load: Invalid argument. See system logs and 'systemctl status sshd.service' for details.")
      journalctl_logs = <<-EOS
      -- Logs begin at Tue 2016-06-14 11:59:21 UTC, end at Tue 2016-06-14 21:45:02 UTC. --
Jun 14 21:41:34 foo.example.com systemd[1]: Stopping sshd Service...
Jun 14 21:41:35 foo.example.com systemd[1]: Starting sshd Service...
Jun 14 21:43:23 foo.example.com systemd[1]: sshd.service lacks both ExecStart= and ExecStop= setting. Refusing.
      EOS
      provider.expects(:execute).with("journalctl -n 50 --since '5 minutes ago' -u sshd.service --no-pager").returns(journalctl_logs)
      expect { provider.restart }.to raise_error(Puppet::Error, /Systemd restart for sshd.service failed:journalctl log for sshd.service:       -- Logs begin at Tue 2016-06-14 11:59:21 UTC, end at Tue 2016-06-14 21:45:02 UTC. --/)
    end
  end

  describe "#debian_enabled?" do
    [104, 106].each do |status|
      it "should return true when invoke-rc.d returns #{status}" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
        provider.stubs(:system)
        $CHILD_STATUS.expects(:exitstatus).returns(status)
        expect(provider.debian_enabled?).to eq(:true)
      end
    end

    [101, 105].each do |status|
      it "should return true when status is #{status} and there are at least 4 start links" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
        provider.stubs(:system)
        provider.expects(:get_start_link_count).returns(4)
        $CHILD_STATUS.expects(:exitstatus).twice.returns(status)
        expect(provider.debian_enabled?).to eq(:true)
      end

      it "should return false when status is #{status} and there are less than 4 start links" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
        provider.stubs(:system)
        provider.expects(:get_start_link_count).returns(1)
        $CHILD_STATUS.expects(:exitstatus).twice.returns(status)
        expect(provider.debian_enabled?).to eq(:false)
      end
    end
  end

  describe "#get_start_link_count" do
    it "should strip the '.service' from the search if present in the resource name" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      Dir.expects(:glob).with("/etc/rc*.d/S??sshd").returns(['files'])
      provider.get_start_link_count
    end

    it "should use the full service name if it does not include '.service'" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      Dir.expects(:glob).with("/etc/rc*.d/S??sshd").returns(['files'])
      provider.get_start_link_count
    end
  end

  it "(#16451) has command systemctl without being fully qualified" do
    expect(described_class.instance_variable_get(:@commands)).to include(:systemctl => 'systemctl')
  end
end
