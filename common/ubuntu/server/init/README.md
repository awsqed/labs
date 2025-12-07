# Ubuntu Server 24.04 Init & Hardening Script

24-step security hardening automation with resume capability.

## Requirements

- Ubuntu Server 24.04 LTS
- Root/sudo privileges
- Active internet connection

## Configuration

Required variables in `.env.init`:
```bash
NEW_USER="username"
SSH_PORT="22"
SSH_PUBLIC_KEY="ssh-rsa AAAA..."
MAIL_HOSTNAME="mail.example.com"
USER_PASSWORD=""  # Optional for non-interactive
```

## Execution

```bash
sudo ./init.sh                  # Normal execution
sudo ./init.sh --continue N     # Resume from step N
sudo ./init.sh --restart        # Start over
sudo USER_PASSWORD='pass' ./init.sh  # Non-interactive
sudo CONFIG_FILE=/path/to/.env ./init.sh  # Custom config
```

## Script Steps

| Step | Description |
|------|-------------|
| 1 | System updates & unattended-upgrades |
| 2 | Create sudo user |
| 3 | SSH hardening |
| 4 | CrowdSec IDS/IPS |
| 5 | UFW firewall |
| 6 | Postfix mail server |
| 7 | Docker + ufw-docker (optional) |
| 8 | Auditd |
| 9 | Lynis |
| 10 | Rkhunter |
| 11 | Secure shared memory |
| 12 | Persistent journald |
| 13 | AIDE file integrity |
| 14 | Kernel security |
| 15 | AppArmor Docker |
| 16 | Docker runtime security |
| 17 | Secure tmpfs |
| 18 | PAM account lockout |
| 19 | Kernel module blacklist |
| 20 | DNS security |
| 21 | Automated audits |
| 22 | Log monitoring |
| 23 | File permissions |
| 24 | Cleanup |

## Documentation

| Document | Purpose |
|----------|---------|
| **README.md** | Deployment specs |
| **DEVELOPER-GUIDE.md** | Modification patterns |
| **NEW-STEP-TEMPLATE.sh** | Feature template |
| **.env.init.example** | Config template |

## Verification Commands

```bash
sudo sshd -t
sudo aa-status
resolvectl status
mount | grep tmpfs
sudo ufw status verbose
sudo cscli metrics
sudo check-docker-security
sudo weekly-security-audit
sudo daily-log-check
```

## Files Created

```
/etc/ssh/sshd_config.d/99-custom.conf
/etc/crowdsec/profiles.yaml
/etc/docker/daemon.json
/etc/apparmor.d/docker-default
/etc/audit/rules.d/custom.rules
/etc/security/faillock.conf
/etc/systemd/resolved.conf.d/dns-security.conf
/etc/sysctl.d/99-security.conf
/etc/modprobe.d/blacklist-*.conf
/etc/apt/apt.conf.d/50unattended-upgrades
/usr/local/bin/check-docker-security
/usr/local/bin/weekly-security-audit
/usr/local/bin/daily-log-check
/etc/cron.weekly/aide-check
/etc/cron.weekly/security-audit
/etc/cron.daily/security-log-check
/var/log/server-init-progress.log
/var/tmp/server-init-step
```

## Configuration Variables

| Variable | Required | Validation |
|----------|----------|------------|
| `NEW_USER` | Yes | Valid username format |
| `SSH_PORT` | Yes | 1-65535 |
| `SSH_PUBLIC_KEY` | Yes | Valid SSH key format |
| `MAIL_HOSTNAME` | Yes | Valid FQDN |
| `USER_PASSWORD` | No | For non-interactive mode |

## Development Rules

**CRITICAL**: File Permissions (N-1) and Cleanup (N) must always be final two steps. Insert new steps BEFORE File Permissions, then renumber.

**Standards:**
- Resume capability required
- Progress logging required
- Error handling required
- Use `mktemp` for temp files
- Validate before applying
- Backup before overwriting
- Set PATH in cron scripts
- Test in VM before production
