require 'beaker-rspec'
require 'beaker/puppet_install_helper'

run_puppet_install_helper unless ENV['BEAKER_provision'] == 'no'

UNSUPPORTED_PLATFORMS = ['AIX','Solaris']

RSpec.configure do |c|
  # Project root
  proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    # Install module and dependencies
    hosts.each do |host|
      shell('rm -rf /etc/puppet/modules/systemd_logs/petems-systemd_logs')
      shell('rm -rf /etc/puppet/modules/petems-systemd_logs')
      shell('rm -rf /etc/puppet/modules/systemd_logs/')
      copy_module_to(host, :source => proj_root, :module_name => 'systemd_logs')
    end
  end
end
