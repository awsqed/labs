# Ubuntu Server 24.04 Init & Hardening Script

Comprehensive initialization and security hardening for Ubuntu Server 24.04 with resume capability and 24 hardening steps.

## Features

- SSH hardening (key-only auth, custom port, cipher restrictions)
- CrowdSec IDS/IPS with blocklists
- UFW firewall with rate limiting
- AppArmor for Docker
- PAM account lockout
- Auditd monitoring
- AIDE file integrity
- Kernel hardening
- DNS security (DNSSEC + DNS-over-TLS)
- Automatic security updates
- Resume from any step after failure
- Non-interactive mode support

## Requirements

- Ubuntu Server 24.04 LTS
- Root or sudo privileges
- Active internet connection
- Time: 15-30 minutes

## Installation

### 1. Download
```bash
git clone <repository-url>
cd ubuntu-server/init
```

### 2. Configure
```bash
cp .env.init.example .env.init
nano .env.init
```

Required settings:
```bash
NEW_USER="your_username"
SSH_PORT="22"
SSH_PUBLIC_KEY="ssh-rsa AAAA..."
MAIL_HOSTNAME="mail.example.com"
USER_PASSWORD=""  # Optional for non-interactive mode
```

### 3. Run
```bash
# Normal
sudo ./init.sh

# Non-interactive
sudo USER_PASSWORD='password' ./init.sh

# Custom config
sudo CONFIG_FILE=.env.prod ./init.sh
```

## Script Steps

| Step | Description | Time |
|------|-------------|------|
| 1 | System updates & unattended-upgrades | 2-5 min |
| 2 | Create sudo user | 1 min |
| 3 | SSH hardening | 1 min |
| 4 | CrowdSec IDS/IPS | 2-3 min |
| 5 | UFW firewall | 1 min |
| 6 | Postfix mail server | 1 min |
| 7 | Docker + ufw-docker (optional) | 2-3 min |
| 8 | Auditd | 1 min |
| 9 | Lynis | 1 min |
| 10 | Rkhunter | 1 min |
| 11 | Secure shared memory | <1 min |
| 12 | Persistent journald | <1 min |
| 13 | AIDE file integrity | 10-15 min |
| 14 | Kernel security | <1 min |
| 15 | AppArmor Docker | 1 min |
| 16 | Docker runtime security | 1 min |
| 17 | Secure tmpfs | <1 min |
| 18 | PAM account lockout | <1 min |
| 19 | Kernel module blacklist | 1 min |
| 20 | DNS security | <1 min |
| 21 | Automated audits | <1 min |
| 22 | Log monitoring | <1 min |
| 23 | File permissions | <1 min |
| 24 | Cleanup | <1 min |

Total: 15-30 minutes (AIDE initialization is longest)

## Resume After Failure

```bash
# Automatic prompt
sudo ./init.sh

# Manual resume
sudo ./init.sh --continue N

# Start over
sudo ./init.sh --restart
```

## Documentation

| Document | Purpose | AI Use |
|----------|---------|--------|
| **README.md** (this file) | Deployment and usage guide | Installation/deployment tasks |
| **[DEVELOPER-GUIDE.md](./DEVELOPER-GUIDE.md)** | Complete patterns and rules | Modification/development tasks |
| **[NEW-STEP-TEMPLATE.sh](./NEW-STEP-TEMPLATE.sh)** | Template for adding steps | Copy for new features |
| **.env.init.example** | Configuration template | Generate config files |

### AI Agent Usage
- **For deployment**: Read **README.md** for configuration and usage
- **For modifications**: Read **DEVELOPER-GUIDE.md** for patterns and rules
- **For new steps**: Copy **NEW-STEP-TEMPLATE.sh** as starting point

## Usage Examples

### Basic
```bash
cp .env.init.example .env.init
nano .env.init
sudo ./init.sh

# Test SSH on new port BEFORE logging out
ssh -p YOUR_PORT YOUR_USER@YOUR_IP

# Reboot
sudo reboot
```

### Advanced
```bash
# Continue from step 10
sudo ./init.sh --continue 10

# Custom config file
sudo CONFIG_FILE=/path/to/custom.env ./init.sh

# Non-interactive
sudo USER_PASSWORD='SecurePass123!' ./init.sh

# Help
./init.sh --help
```

## Verification

```bash
# SSH
sudo sshd -t

# AppArmor
sudo aa-status

# DNS
resolvectl status

# Tmpfs
mount | grep tmpfs

# Firewall
sudo ufw status verbose

# CrowdSec
sudo cscli metrics

# Docker (if installed)
sudo check-docker-security

# Mail
echo 'Test' | mail -s 'Test' root

# Audits
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

## Security Considerations

### SSH Access
CRITICAL: Test SSH on new port BEFORE logging out.

```bash
# From another terminal
ssh -p NEW_PORT NEW_USER@SERVER_IP
# Keep original session open until verified
```

### Root Access
- Root SSH login disabled
- Root password login disabled
- Use new user with sudo

### Account Lockout
- 5 failed attempts = locked 15 minutes
- Root locked 10 minutes
- Unlock: `sudo faillock --user USERNAME --reset`

### Firewall
- Default: deny incoming, allow outgoing
- SSH: rate-limited (6 connections/30s)
- Add rules: `sudo ufw allow PORT/tcp`

### Docker Security
If installed:
- AppArmor profile enforced
- No new privileges by default
- Use: `sudo ufw-docker allow CONTAINER PORT`

## Troubleshooting

### Script Fails at Step N
```bash
sudo cat /var/log/server-init-progress.log
sudo ./init.sh --continue $((N+1))
sudo ./init.sh --restart
```

### SSH Connection Refused
```bash
sudo systemctl status ssh
sudo ss -tlnp | grep ssh
sudo ufw status
sudo sshd -t
sudo journalctl -u ssh -n 50
```

### Service Won't Start
```bash
sudo systemctl status SERVICE_NAME
sudo journalctl -u SERVICE_NAME -n 50
```

### Lock File Error
```bash
sudo rm -f /var/lock/server-init-script.lock
sudo ./init.sh
```

## Configuration Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `NEW_USER` | Yes | Username for admin account |
| `SSH_PORT` | Yes | SSH port (1-65535) |
| `SSH_PUBLIC_KEY` | Yes | SSH public key |
| `MAIL_HOSTNAME` | Yes | Server FQDN |
| `USER_PASSWORD` | No | Password for non-interactive mode |

Script validates:
- SSH_PORT: 1-65535
- SSH_PUBLIC_KEY: Valid format
- MAIL_HOSTNAME: Valid FQDN
- NEW_USER: Valid username format

## Production Deployment

1. Test in VM
```bash
multipass launch --name test-server
multipass shell test-server
```

2. Customize config
```bash
cp .env.init.example .env.init
# Edit with production values
```

3. Run script
```bash
sudo ./init.sh
```

4. Verify
```bash
sudo weekly-security-audit
```

5. Reboot
```bash
sudo reboot
```

## AI Development Instructions

When modifying this script, reference **[DEVELOPER-GUIDE.md](./DEVELOPER-GUIDE.md)** for patterns and rules.

CRITICAL RULE: File Permissions (Step N-1) and Cleanup (Step N) must always be final two steps. Insert new steps BEFORE File Permissions, then renumber.

AI workflow:
1. Copy **[NEW-STEP-TEMPLATE.sh](./NEW-STEP-TEMPLATE.sh)**
2. Follow **[DEVELOPER-GUIDE.md](./DEVELOPER-GUIDE.md)** patterns
3. Test in VM before deployment
4. Update all documentation

### Mandatory Code Standards

- File Permissions and Cleanup must always be final two steps
- New steps inserted BEFORE File Permissions, not after Cleanup
- All steps must have resume capability
- All steps must log progress
- All steps must handle errors gracefully
- Use `mktemp` for temp files
- Validate before applying changes
- Backup before overwriting files
- Set PATH in cron scripts
- Test in VM before production

## License

Personal Use - AI Generated

## Technology Stack

This script leverages:
- Ubuntu Security features
- CrowdSec IDS/IPS
- Docker security framework
- AppArmor profiles

## Changelog

### Version 1.0 (2025-11-22)
- 24 comprehensive hardening steps
- Resume capability
- Docker support with security profiles
- CrowdSec integration
- DNS security (DNSSEC + DoT)
- Automated monitoring and auditing
- Complete AI-readable documentation

Last Updated: 2025-11-22
Purpose: Personal use - AI-generated scripts
Status: Production Ready
