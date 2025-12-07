# Ubuntu Server 24.04 Init & Hardening Script

24-step security hardening automation for Ubuntu Server 24.04 with resume capability.

## Features

- SSH hardening (key-only, custom port, cipher restrictions)
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

## Requirements

- Ubuntu Server 24.04 LTS
- Root/sudo privileges
- Active internet connection
- Time: 15-30 minutes (AIDE initialization longest)

## Quick Start

```bash
cd ubuntu-server/init
cp .env.init.example .env.init
nano .env.init                  # Configure required settings
sudo ./init.sh
```

**Required Settings:**
```bash
NEW_USER="your_username"
SSH_PORT="22"
SSH_PUBLIC_KEY="ssh-rsa AAAA..."
MAIL_HOSTNAME="mail.example.com"
USER_PASSWORD=""  # Optional for non-interactive mode
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

## Resume After Failure

```bash
sudo ./init.sh                  # Auto-prompts to resume
sudo ./init.sh --continue N     # Resume from step N
sudo ./init.sh --restart        # Start over
```

## Usage Examples

**Basic:**
```bash
cp .env.init.example .env.init
nano .env.init
sudo ./init.sh

# Test SSH BEFORE logging out
ssh -p YOUR_PORT YOUR_USER@YOUR_IP

sudo reboot
```

**Non-interactive:**
```bash
sudo USER_PASSWORD='SecurePass123!' ./init.sh
```

**Custom config:**
```bash
sudo CONFIG_FILE=/path/to/custom.env ./init.sh
```

## Documentation

| Document | Purpose | AI Use |
|----------|---------|--------|
| **README.md** (this) | Deployment/usage | Installation tasks |
| **DEVELOPER-GUIDE.md** | Patterns/rules | Modification tasks |
| **NEW-STEP-TEMPLATE.sh** | Template | Copy for new features |
| **.env.init.example** | Config template | Generate configs |

## Verification

```bash
sudo sshd -t                    # SSH config
sudo aa-status                  # AppArmor
resolvectl status               # DNS
mount | grep tmpfs              # Tmpfs
sudo ufw status verbose         # Firewall
sudo cscli metrics              # CrowdSec
sudo check-docker-security      # Docker (if installed)
echo 'Test' | mail -s 'Test' root  # Mail
sudo weekly-security-audit      # Audits
sudo daily-log-check            # Logs
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
**CRITICAL**: Test SSH on new port BEFORE logging out.

```bash
# From another terminal
ssh -p NEW_PORT NEW_USER@SERVER_IP
# Keep original session open until verified
```

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

| Issue | Commands |
|-------|----------|
| **Script fails at step N** | `sudo cat /var/log/server-init-progress.log`<br>`sudo ./init.sh --continue $((N+1))` |
| **SSH connection refused** | `sudo systemctl status ssh`<br>`sudo ss -tlnp \| grep ssh`<br>`sudo sshd -t` |
| **Service won't start** | `sudo systemctl status SERVICE`<br>`sudo journalctl -u SERVICE -n 50` |
| **Lock file error** | `sudo rm -f /var/lock/server-init-script.lock` |

## Configuration Variables

| Variable | Required | Validation |
|----------|----------|------------|
| `NEW_USER` | Yes | Valid username format |
| `SSH_PORT` | Yes | 1-65535 |
| `SSH_PUBLIC_KEY` | Yes | Valid SSH key format |
| `MAIL_HOSTNAME` | Yes | Valid FQDN |
| `USER_PASSWORD` | No | For non-interactive mode |

## Production Deployment

1. **Test in VM:**
   ```bash
   multipass launch --name test-server
   multipass shell test-server
   ```

2. **Configure:**
   ```bash
   cp .env.init.example .env.init
   # Edit with production values
   ```

3. **Run:**
   ```bash
   sudo ./init.sh
   ```

4. **Verify:**
   ```bash
   sudo weekly-security-audit
   ```

5. **Reboot:**
   ```bash
   sudo reboot
   ```

## AI Development Instructions

**Reference**: DEVELOPER-GUIDE.md for patterns and rules.

**CRITICAL RULE**: File Permissions (N-1) and Cleanup (N) must always be final two steps. Insert new steps BEFORE File Permissions, then renumber.

**Workflow:**
1. Copy NEW-STEP-TEMPLATE.sh
2. Follow DEVELOPER-GUIDE.md patterns
3. Test in VM before deployment
4. Update all documentation

### Mandatory Standards

- File Permissions and Cleanup final two steps
- New steps inserted BEFORE File Permissions
- Resume capability required
- Progress logging required
- Error handling required
- Use `mktemp` for temp files
- Validate before applying
- Backup before overwriting
- Set PATH in cron scripts
- Test in VM before production

## Technology Stack

- Ubuntu Security features
- CrowdSec IDS/IPS
- Docker security framework
- AppArmor profiles
