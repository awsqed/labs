# Systemd Service File Standard

Apply to ALL .service file operations in this repository.

## Required Actions

When creating/modifying systemd .service files:
- Follow template structure exactly
- Maintain directive ordering specified below
- Include all mandatory sections
- Validate: `systemd-analyze verify` before completion

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

| Type | Behavior | Use With |
|------|----------|----------|
| **simple** | Main process in ExecStart | Default, long-running daemons |
| **forking** | Process forks, parent exits | PIDFile= |
| **oneshot** | Short-lived task | RemainAfterExit=yes |
| **notify** | Sends readiness notification | sd_notify() |
| **dbus** | Acquires D-Bus name | D-Bus services |

## Restart Values

| Value | Behavior |
|-------|----------|
| **on-failure** | Restart on non-zero exit, signals, timeouts (RECOMMENDED) |
| **always** | Always restart regardless of exit status |
| **no** | Never restart (default) |

**CRITICAL**: StartLimitBurst and StartLimitIntervalSec belong in [Unit], NOT [Service].

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

**ProtectSystem levels:**
- **strict**: Entire filesystem read-only except /dev, /proc, /sys
- **full**: /usr, /boot, /efi read-only
- **yes**: /usr, /boot read-only

## Requirements

**MUST HAVE:**
- [Unit] with Description
- [Service] with Type and ExecStart
- [Install] with WantedBy
- Absolute paths for all executables
- Proper directive ordering

**RECOMMENDED:**
- After= dependencies
- Restart=on-failure for daemons
- StandardOutput/StandardError=journal
- SyslogIdentifier matching service name
- User/Group (non-root when possible)
- Security hardening directives

**FORBIDDEN:**
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

## File Locations

- Custom services: `/etc/systemd/system/myapp.service`
- Package-managed: `/usr/lib/systemd/system/myapp.service`
- User services: `~/.config/systemd/user/myapp.service`
