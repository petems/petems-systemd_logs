# petems-systemd_logs

[![Build Status](https://travis-ci.org/petems/petems-systemd_logs.svg?branch=master)](https://travis-ci.org/petems/petems-systemd_logs)

## Usage

```puppet
service{ "foo":
  ensure   => "running",
  provider => systemd_logs,
}
```

## What is this?

This is a basic workaround module for PUP-5604.

It adds an extra execution of journald when services fail, giving a much more detailed log of why a service failed.

## Example

Error with regular systemd provider:

```
Error: Could not start Service[foo]: Execution of '/usr/bin/systemctl start foo' returned 6: Failed to start foo.service: Unit foo.service failed to load: Invalid argument. See system logs and 'systemctl status foo.service' for details.
```

Error with `systemd_logs`:

```
Error: Systemd start for foo failed:journalctl log for foo: -- Logs begin at Mon 2016-06-20 12:07:17 UTC, end at Mon 2016-06-20 12:08:06 UTC. --
Jun 20 12:08:06 centos-7-x64 systemd[1]: foo.service lacks both ExecStart= and ExecStop= setting. Refusing.
Jun 20 12:08:06 centos-7-x64 systemd[1]: foo.service lacks both ExecStart= and ExecStop= setting. Refusing.
```
