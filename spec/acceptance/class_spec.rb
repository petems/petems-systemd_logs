require 'spec_helper_acceptance'

describe 'shows errors on failure' do

  it 'should run successfully' do
    pp = <<-EOS
    file { '/usr/lib/systemd/system/foo.service':
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      source => "puppet:///modules/systemd_logs/foo.service",
    }
    ~>
    exec {
    'systemctl-daemon-reload':
      command => 'systemctl daemon-reload',
      path    => $::path,
    }
    ~>
    service { 'foo':
      ensure   => running,
      provider => 'systemd_logs',
    }

    EOS

    apply_manifest(pp, :catch_failures => false) do |r|
      expect(r.stderr).to match(/Error: Systemd start for foo failed:journalctl log for foo: -- Logs begin at/)
      expect(r.stderr).to match(/systemd\[1\]: foo.service lacks both ExecStart= and ExecStop= setting. Refusing./)
    end
  end
end
