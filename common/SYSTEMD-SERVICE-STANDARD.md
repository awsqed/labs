# Systemd Service File Standard

Version: 1.0 | Last Updated: 2025-11-22

Apply this standard to ALL .service file operations in this repository.

## Required Actions

When creating/modifying systemd .service files:
- Follow template structure exactly
- Maintain directive ordering specified below
- Include all mandatory sections
- Validate syntax with `systemd-analyze verify` before completion

## Standard Template

```ini
[Unit]
Description=Brief description (one line, no period)
Documentation=https://example.com/docs man:service(8)
After=network.target syslog.target
Wants=network-online.target
Requires=
Before=
Conflicts=
StartLimitBurst=3
StartLimitIntervalSec=60

[Service]
Type=simple
User=username
Group=groupname
WorkingDirectory=/path/to/working/directory

Environment="VAR1=value1"
Environment="VAR2=value2"
EnvironmentFile=-/etc/default/servicename

ExecStartPre=/path/to/pre-start-command
ExecStart=/path/to/executable --options
ExecStartPost=/path/to/post-start-command
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/path/to/stop-command

Restart=on-failure
RestartSec=5s

PrivateTmp=yes
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/servicename

LimitNOFILE=65536
MemoryLimit=1G

StandardOutput=journal
StandardError=journal
SyslogIdentifier=servicename

KillMode=mixed
TimeoutStartSec=90
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

## Directive Order

### [Unit] Section
1. Description (REQUIRED)
2. Documentation
3. After
4. Before
5. Requires
6. Wants
7. Conflicts
8. StartLimitBurst
9. StartLimitIntervalSec

### [Service] Section
1. Type (REQUIRED)
2. User, Group, WorkingDirectory
3. Environment, EnvironmentFile
4. ExecStartPre, ExecStart (REQUIRED), ExecStartPost, ExecReload, ExecStop
5. Restart, RestartSec
6. Security directives
7. Resource limits
8. Logging (StandardOutput, StandardError, SyslogIdentifier)
9. Process management (KillMode, Timeouts)

### [Install] Section
1. WantedBy (REQUIRED)
2. RequiredBy
3. Also

## Service Types

- **simple**: Main process in ExecStart (default)
- **forking**: Process forks, parent exits. Use with PIDFile=
- **oneshot**: Short-lived. Use with RemainAfterExit=yes
- **notify**: Sends readiness via sd_notify()
- **dbus**: Acquires D-Bus name

## Restart Values

- **on-failure**: Restart on non-zero exit, signals, timeouts (RECOMMENDED)
- **always**: Always restart
- **no**: Never restart (default)

**CRITICAL**: StartLimitBurst and StartLimitIntervalSec belong in [Unit] section, NOT [Service].

## Security Hardening

```ini
PrivateTmp=yes
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/servicename
PrivateDevices=yes
ProtectKernelTunables=yes
RestrictRealtime=yes
```

ProtectSystem levels:
- **strict**: Entire filesystem read-only except /dev, /proc, /sys
- **full**: /usr, /boot, /efi read-only
- **yes**: /usr, /boot read-only

## Common Patterns

Wait for network:
```ini
[Unit]
After=network-online.target
Wants=network-online.target
```

Database dependency:
```ini
[Unit]
Requires=postgresql.service
After=postgresql.service
```

Graceful reload:
```ini
[Service]
ExecReload=/bin/kill -HUP $MAINPID
```

## Type-Specific Templates

### Simple Service
```ini
[Unit]
Description=My Application Server
After=network.target

[Service]
Type=simple
User=myapp
WorkingDirectory=/opt/myapp
ExecStart=/usr/bin/myapp --config /etc/myapp/config.yaml
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=myapp

[Install]
WantedBy=multi-user.target
```

### Forking Service
```ini
[Unit]
Description=My Daemon
After=network.target

[Service]
Type=forking
PIDFile=/run/mydaemon.pid
ExecStart=/usr/sbin/mydaemon
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### Oneshot Service
```ini
[Unit]
Description=Initialization Script
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/init-script.sh
RemainAfterExit=yes
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

### Container-Dependent Service
```ini
[Unit]
Description=Service Depending on Docker
After=docker.service
Requires=docker.service
StartLimitBurst=5
StartLimitIntervalSec=60

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/sleep 5
ExecStart=/usr/local/bin/container-setup.sh
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
```

## Mandatory Requirements

MUST HAVE:
- [Unit] with Description
- [Service] with Type and ExecStart
- [Install] with WantedBy
- Absolute paths for all executables
- Proper directive ordering

RECOMMENDED:
- After= dependencies
- Restart=on-failure for daemons
- StandardOutput/StandardError=journal
- SyslogIdentifier matching service name
- User/Group (non-root when possible)
- Security hardening directives

FORBIDDEN:
- Relative paths
- Hardcoded credentials
- Missing blank lines between sections
- Trailing whitespace
- Periods at end of Description

## Validation Commands

```bash
systemd-analyze verify /etc/systemd/system/myapp.service
systemd-analyze security myapp.service
systemctl daemon-reload
systemctl start myapp.service
systemctl status myapp.service
journalctl -u myapp.service -f
```

## Troubleshooting

Service fails to start:
```bash
systemctl status myapp.service
journalctl -u myapp.service -n 50
systemd-analyze verify myapp.service
```

Service crashes:
```bash
journalctl -u myapp.service -f
sudo -u serviceuser /path/to/executable
systemctl show myapp.service | grep StartLimit
```

Dependencies not working:
```bash
systemctl list-dependencies myapp.service
systemd-analyze plot > boot.svg
```

## File Locations

- Custom services: `/etc/systemd/system/myapp.service`
- Package-managed: `/usr/lib/systemd/system/myapp.service`
- User services: `~/.config/systemd/user/myapp.service`

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-22 | Initial standard |
