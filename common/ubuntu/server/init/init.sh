#!/bin/bash

# Ubuntu Server 24.04 Initialization Script
# Run as root or with sudo

set -euo pipefail

# ============================================================================
# CONFIGURATION - LOAD FROM .env.init FILE
# ============================================================================

# Path to configuration file
CONFIG_FILE="${CONFIG_FILE:-.env.init}"

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file '$CONFIG_FILE' not found!"
    echo ""
    echo "Create a .env.init file with your configuration:"
    echo "  NEW_USER=\"your_username\""
    echo "  SSH_PORT=\"22\""
    echo "  SSH_PUBLIC_KEY=\"ssh-rsa AAAA...\""
    echo "  MAIL_HOSTNAME=\"mail.example.com\""
    echo "  USER_PASSWORD=\"\"  # Optional"
    echo ""
    echo "Or use the example file:"
    echo "  cp .env.init.example .env.init"
    echo "  nano .env.init"
    exit 1
fi

# Load configuration from .env.init
set +u  # Temporarily disable unbound variable check
source "$CONFIG_FILE"
set -u  # Re-enable it
echo "Configuration loaded from $CONFIG_FILE"

# Set defaults for optional variables
USER_PASSWORD="${USER_PASSWORD:-}"

# ============================================================================
# CONSTANTS
# ============================================================================

readonly PROGRESS_FILE="/var/log/server-init-progress.log"
readonly STEP_FILE="/var/tmp/server-init-step"
readonly LOCK_FILE="/var/lock/server-init-script.lock"
readonly TOTAL_STEPS=24

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Global variables
LAST_STEP=0
START_FROM_STEP=0

# Step names for error reporting
declare -a STEP_NAMES=(
    ""
    "System Updates"
    "Create New User"
    "SSH Configuration"
    "CrowdSec"
    "UFW Firewall"
    "Postfix Mail Server"
    "Docker + ufw-docker"
    "Auditd"
    "Lynis"
    "Rkhunter"
    "Secure Shared Memory"
    "Persistent Logging"
    "AIDE"
    "Additional Security"
    "AppArmor Docker Security"
    "Docker Runtime Security"
    "Secure Tmpfs"
    "PAM Account Lockout"
    "Kernel Module Blacklist"
    "DNS Security"
    "Automated Security Audits"
    "Log Monitoring"
    "File Permissions"
    "Cleanup"
)

# ============================================================================
# INITIALIZATION
# ============================================================================

# Initialize logging
init_logging() {
    if ! touch "$PROGRESS_FILE" 2>/dev/null; then
        echo "ERROR: Cannot write to $PROGRESS_FILE, using /tmp"
        PROGRESS_FILE="/tmp/server-init-progress.log"
        touch "$PROGRESS_FILE"
    fi
    chmod 640 "$PROGRESS_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
       echo -e "${RED}[ERROR]${NC} This script must be run as root or with sudo"
       exit 1
    fi
}

# Initialize
init_logging
check_root

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$PROGRESS_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $1" >> "$PROGRESS_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$PROGRESS_FILE"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Check if Docker is installed dynamically
check_docker_installed() {
    command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker 2>/dev/null
}

# Save progress
save_progress() {
    echo "LAST_COMPLETED_STEP=$1" > "$STEP_FILE"
    LAST_STEP=$1
    log_info "Completed step $1: ${STEP_NAMES[$1]}"
}

# Load last completed step
load_progress() {
    if [ -f "$STEP_FILE" ]; then
        source "$STEP_FILE"
        return $LAST_COMPLETED_STEP
    fi
    return 0
}

# Error handler
error_handler() {
    local line_no=$1
    local step_name="${STEP_NAMES[$LAST_STEP]:-Unknown}"

    log_error "Script failed at line $line_no during Step $LAST_STEP: $step_name"
    log_error "Check the log file: $PROGRESS_FILE"
    log_error ""
    log_error "To resume from step $((LAST_STEP + 1)), run:"
    log_error "  sudo $0 --continue $((LAST_STEP + 1))"
    log_error ""
    log_error "To start over from the beginning, run:"
    log_error "  sudo $0 --restart"

    # Release lock
    flock -u 200 2>/dev/null || true

    exit 1
}

# Set error trap
trap 'error_handler ${LINENO}' ERR

# Add trap for normal exit to clean up lock file
trap 'flock -u 200 2>/dev/null || true; rm -f "$LOCK_FILE" 2>/dev/null || true' EXIT

# Validate step number
validate_step() {
    local step=$1
    if ! [[ "$step" =~ ^[0-9]+$ ]] || [ "$step" -lt 1 ] || [ "$step" -gt $TOTAL_STEPS ]; then
        log_error "Invalid step number. Must be between 1 and $TOTAL_STEPS."
        exit 1
    fi
}

# Validate configuration inputs
validate_config() {
    # Validate SSH_PORT
    if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
        log_error "Invalid SSH_PORT: $SSH_PORT (must be 1-65535)"
        exit 1
    fi

    # Validate SSH key format
    if ! [[ "$SSH_PUBLIC_KEY" =~ ^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)[[:space:]] ]]; then
        log_error "Invalid SSH_PUBLIC_KEY format (must start with ssh-rsa, ssh-ed25519, or ecdsa-sha2-*)"
        exit 1
    fi

    # Validate hostname format
    if ! [[ "$MAIL_HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "Invalid MAIL_HOSTNAME format"
        exit 1
    fi

    # Validate NEW_USER format
    if ! [[ "$NEW_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        log_error "Invalid NEW_USER format (must be lowercase alphanumeric with - or _)"
        exit 1
    fi
}

# Check OS compatibility
check_os() {
    if [ ! -f /etc/os-release ]; then
        log_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi

    source /etc/os-release

    if [[ ! "$ID" =~ ^(ubuntu|debian)$ ]]; then
        log_error "This script is for Ubuntu/Debian only. Detected: $ID"
        exit 1
    fi

    if [[ "$ID" == "ubuntu" ]] && [[ ! "$VERSION_ID" =~ ^24\. ]]; then
        log_warn "Script designed for Ubuntu 24.04. You have: $VERSION_ID"
        if [ -t 0 ]; then
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
        else
            log_warn "Non-interactive mode, proceeding with caution..."
        fi
    fi

    log_info "Detected: $PRETTY_NAME"
}

# Check network connectivity (IPv4 and IPv6)
check_network() {
    log_info "Checking network connectivity..."
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null && ! ping6 -c 1 -W 2 2001:4860:4860::8888 &>/dev/null; then
        log_error "No network connectivity detected (IPv4 or IPv6)"
        exit 1
    fi
}

# Backup existing file
backup_file() {
    local file=$1
    if [ -f "$file" ]; then
        local backup="${file}.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up $file to $backup"
    fi
}

# Display help
show_help() {
    cat << EOF
Ubuntu Server 24.04 Initialization Script

Usage: $0 [OPTIONS]

Options:
  --continue N    Continue from step N (1-${TOTAL_STEPS})
  --restart       Start from beginning, ignore previous progress
  --help, -h      Show this help message

Steps:
  1  - System updates
  2  - Create new user
  3  - SSH configuration
  4  - CrowdSec
  5  - UFW firewall
  6  - Postfix mail server
  7  - Docker + ufw-docker (optional)
  8  - Auditd
  9  - Lynis
  10 - Rkhunter
  11 - Secure shared memory
  12 - Persistent logging
  13 - AIDE
  14 - Additional security settings (sysctl)
  15 - AppArmor Docker security
  16 - Docker runtime security
  17 - Tmpfs configuration (/tmp, /var/tmp)
  18 - PAM account lockout (faillock)
  19 - Kernel module blacklist
  20 - DNS security (DNSSEC, DoT)
  21 - Automated security audits
  22 - Log monitoring
  23 - File permissions
  24 - Cleanup

Configuration:
  Create a .env.init file in the same directory with:
    NEW_USER="your_username"
    SSH_PORT="22"
    SSH_PUBLIC_KEY="ssh-rsa AAAA..."
    MAIL_HOSTNAME="mail.example.com"
    USER_PASSWORD=""  # Optional

Environment Variables:
  CONFIG_FILE     - Path to config file (default: .env.init)
  USER_PASSWORD   - Optional: Password for new user (for automation)

Examples:
  sudo $0                    # Run normally with .env.init
  sudo $0 --continue 5       # Continue from step 5
  sudo $0 --restart          # Start over
  sudo CONFIG_FILE=.env.prod $0  # Use custom config file
  sudo USER_PASSWORD='secret' $0  # Non-interactive

EOF
    exit 0
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

if [[ "${1:-}" == "--continue" ]]; then
    START_FROM_STEP=${2:-0}
    validate_step "$START_FROM_STEP"
    log_info "Continuing from step $START_FROM_STEP"
elif [[ "${1:-}" == "--restart" ]]; then
    rm -f "$STEP_FILE"
    log_info "Starting from beginning (restart mode)"
elif [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    show_help
else
    # Check if there's incomplete progress
    if load_progress; then
        LAST_COMPLETED=$?
        if [ $LAST_COMPLETED -gt 0 ]; then
            log_warn "Previous incomplete run detected."
            log_warn "Last completed step: $LAST_COMPLETED (${STEP_NAMES[$LAST_COMPLETED]})"

            if [ -t 0 ]; then
                echo ""
                echo "Options:"
                echo "  1) Continue from step $((LAST_COMPLETED + 1))"
                echo "  2) Start over from beginning"
                echo "  3) Exit"
                echo ""
                read -p "Choose [1-3]: " -n 1 -r choice
                echo ""
                case $choice in
                    1)
                        START_FROM_STEP=$((LAST_COMPLETED + 1))
                        log_info "Continuing from step $START_FROM_STEP"
                        ;;
                    2)
                        rm -f "$STEP_FILE"
                        log_info "Starting from beginning"
                        ;;
                    *)
                        exit 0
                        ;;
                esac
            else
                log_info "Non-interactive mode: continuing from step $((LAST_COMPLETED + 1))"
                START_FROM_STEP=$((LAST_COMPLETED + 1))
            fi
        fi
    fi
fi

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================

# Acquire lock to prevent parallel execution
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    log_error "Another instance is already running"
    exit 1
fi

# Validate configuration before proceeding
if [[ "$NEW_USER" == "YOUR_USERNAME" ]] || [[ "$SSH_PUBLIC_KEY" == "YOUR_SSH_PUBLIC_KEY_HERE" ]]; then
    log_error "You must customize NEW_USER and SSH_PUBLIC_KEY before running this script!"
    log_error ""
    log_error "Create a .env.init file with your configuration:"
    log_error "  NEW_USER=\"your_username\""
    log_error "  SSH_PORT=\"22\""
    log_error "  SSH_PUBLIC_KEY=\"ssh-rsa AAAA...\""
    log_error "  MAIL_HOSTNAME=\"mail.example.com\""
    log_error "  USER_PASSWORD=\"\"  # Optional"
    log_error ""
    log_error "Alternatively, set environment variables or edit the script directly."
    exit 1
fi

# Validate all configuration parameters
validate_config

if [[ "$MAIL_HOSTNAME" == "mail.example.com" ]]; then
    log_warn "MAIL_HOSTNAME is still set to default (mail.example.com)."
    log_warn "Update MAIL_HOSTNAME in your .env.init file for proper mail server setup."
fi

# Run pre-flight checks
check_os
check_network

log_info "Starting Ubuntu Server initialization..."
log_info "Configuration: User=$NEW_USER, SSH Port=$SSH_PORT"

# Set timezone to UTC
log_info "Setting timezone to UTC..."
timedatectl set-timezone UTC

# Create common directories
mkdir -p /etc/ssh/sshd_config.d \
         /run/sshd \
         /etc/systemd/journald.conf.d \
         /var/log/journal

# ============================================================================
# STEP 1: SYSTEM UPDATES
# ============================================================================
if [ $START_FROM_STEP -le 1 ]; then
    log_info "Step 1/$TOTAL_STEPS: Updating system packages..."

    export DEBIAN_FRONTEND=noninteractive
    apt update
    apt full-upgrade -y
    apt install -y unattended-upgrades apt-listchanges
    dpkg-reconfigure --priority=low unattended-upgrades

    # Configure unattended-upgrades
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
Unattended-Upgrade::Automatic-Reboot-Time "20:00";
EOF

    apt autoremove --purge -y

    # Set LAST_STEP just before save_progress
    LAST_STEP=1
    save_progress 1
fi

# ============================================================================
# STEP 2: CREATE NEW USER
# ============================================================================
if [ $START_FROM_STEP -le 2 ]; then
    log_info "Step 2/$TOTAL_STEPS: Creating user '$NEW_USER'..."

    if id "$NEW_USER" &>/dev/null; then
        log_warn "User '$NEW_USER' already exists. Skipping creation."
    else
        adduser --disabled-password --gecos "" "$NEW_USER"
        usermod -aG sudo "$NEW_USER"
        log_info "User '$NEW_USER' created and added to sudo group."

        # Set password
        if [ -n "$USER_PASSWORD" ]; then
            echo "$NEW_USER:$USER_PASSWORD" | chpasswd
            log_info "Password set from environment variable."
        elif [ -t 0 ]; then
            log_info "Please set a password for '$NEW_USER' (required for sudo):"
            passwd "$NEW_USER"
        else
            log_warn "Running non-interactively. Set password later with: passwd $NEW_USER"
        fi
    fi

    LAST_STEP=2
    save_progress 2
fi

# ============================================================================
# STEP 3: SSH HARDENING
# ============================================================================
if [ $START_FROM_STEP -le 3 ]; then
    log_info "Step 3/$TOTAL_STEPS: Configuring SSH..."

    # Backup existing config if it exists
    backup_file /etc/ssh/sshd_config.d/99-custom.conf

    # Create SSH privilege separation directory
    mkdir -p /run/sshd
    chmod 0755 /run/sshd

    # Use mktemp for secure temp file creation
    SSHD_TEMP=$(mktemp /tmp/sshd-custom.XXXXXX)

    # Create custom SSH configuration in temp file first
    cat > "$SSHD_TEMP" << EOF
# Custom SSH Security Configuration
Port $SSH_PORT
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
AuthenticationMethods publickey
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
AllowUsers $NEW_USER
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 60
Protocol 2
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
EOF

    # Set up SSH keys for new user
    USER_HOME="/home/$NEW_USER"
    SSH_DIR="$USER_HOME/.ssh"
    AUTH_KEYS="$SSH_DIR/authorized_keys"

    mkdir -p "$SSH_DIR"
    touch "$AUTH_KEYS"

    # Add SSH key (avoid duplicates)
    if ! grep -qF "$SSH_PUBLIC_KEY" "$AUTH_KEYS" 2>/dev/null; then
        echo "$SSH_PUBLIC_KEY" >> "$AUTH_KEYS"
    fi

    # Set correct permissions
    chown -R "$NEW_USER:$NEW_USER" "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    chmod 600 "$AUTH_KEYS"

    # Validate SSH configuration before applying
    if sshd -t -f "$SSHD_TEMP" 2>/dev/null; then
        mv "$SSHD_TEMP" /etc/ssh/sshd_config.d/99-custom.conf
        chmod 600 /etc/ssh/sshd_config.d/99-custom.conf

        # Validate full config
        if sshd -t; then
            systemctl restart ssh
            log_info "SSH configuration updated. New port: $SSH_PORT"
            log_info "Enhanced cipher restrictions applied."
            log_warn "IMPORTANT: Test SSH connection on new port before logging out!"
            log_warn "Test command: ssh -p $SSH_PORT $NEW_USER@<server-ip>"

            LAST_STEP=3
            save_progress 3
        else
            log_error "Full SSH configuration validation failed."
            exit 1
        fi
    else
        rm -f "$SSHD_TEMP"
        log_error "SSH configuration validation failed. Not applying changes."
        exit 1
    fi
fi

# ============================================================================
# STEP 4: CROWDSEC
# ============================================================================
if [ $START_FROM_STEP -le 4 ]; then
    log_info "Step 4/$TOTAL_STEPS: Installing and configuring CrowdSec..."

    CROWDSEC_INSTALLER=$(mktemp)
    log_info "Downloading CrowdSec installer..."
    if curl -fsSL https://install.crowdsec.net -o "$CROWDSEC_INSTALLER"; then
        bash "$CROWDSEC_INSTALLER"
        rm -f "$CROWDSEC_INSTALLER"
    else
        log_error "Failed to download CrowdSec installer"
        rm -f "$CROWDSEC_INSTALLER"
        exit 1
    fi

    # Install CrowdSec
    log_info "Installing CrowdSec package..."
    apt update
    apt install -y crowdsec

    # Verify cscli is installed and available
    if ! command -v cscli &> /dev/null; then
        log_error "CrowdSec installation failed - cscli command not found."
        exit 1
    fi

    # Install collections
    log_info "Installing CrowdSec collections..."
    cscli collections install crowdsecurity/auditd
    cscli collections install crowdsecurity/linux
    cscli collections install crowdsecurity/linux-lpe
    cscli collections install crowdsecurity/sshd
    cscli collections install crowdsecurity/whitelist-good-actors

    # Install bouncer for iptables/nftables
    apt install -y crowdsec-firewall-bouncer-iptables

    # Configure CrowdSec profiles
    log_info "Configuring CrowdSec profiles..."
    backup_file /etc/crowdsec/profiles.yaml

    cat > /etc/crowdsec/profiles.yaml << 'EOF'
name: default_ip_remediation
#debug: true
filters:
 - Alert.Remediation == true && Alert.GetScope() == "Ip"
decisions:
 - type: ban
   duration: 24h
duration_expr: Sprintf('%dh', (GetDecisionsCount(Alert.GetValue()) + 1) * 24)
# notifications:
#   - slack_default  # Set the webhook in /etc/crowdsec/notifications/slack.yaml before enabling this.
#   - splunk_default # Set the splunk url and token in /etc/crowdsec/notifications/splunk.yaml before enabling this.
#   - http_default   # Set the required http parameters in /etc/crowdsec/notifications/http.yaml before enabling this.
#   - email_default  # Set the required email parameters in /etc/crowdsec/notifications/email.yaml before enabling this.
on_success: break
---
name: default_range_remediation
#debug: true
filters:
 - Alert.Remediation == true && Alert.GetScope() == "Range"
decisions:
 - type: ban
   duration: 24h
duration_expr: Sprintf('%dh', (GetDecisionsCount(Alert.GetValue()) + 1) * 24)
# notifications:
#   - slack_default  # Set the webhook in /etc/crowdsec/notifications/slack.yaml before enabling this.
#   - splunk_default # Set the splunk url and token in /etc/crowdsec/notifications/splunk.yaml before enabling this.
#   - http_default   # Set the required http parameters in /etc/crowdsec/notifications/http.yaml before enabling this.
#   - email_default  # Set the required email parameters in /etc/crowdsec/notifications/email.yaml before enabling this.
on_success: break
EOF

    # Restart CrowdSec to apply changes
    systemctl restart crowdsec

    # Verify service started
    if systemctl is-active --quiet crowdsec; then
        log_info "CrowdSec configured and running."
        log_info "Installed collections: auditd, linux, linux-lpe, sshd, whitelist-good-actors"

        LAST_STEP=4
        save_progress 4
    else
        log_error "CrowdSec failed to start. Check logs: journalctl -u crowdsec"
        exit 1
    fi
fi

# ============================================================================
# STEP 5: UFW FIREWALL
# ============================================================================
if [ $START_FROM_STEP -le 5 ]; then
    log_info "Step 5/$TOTAL_STEPS: Configuring UFW firewall..."

    apt install -y ufw

    # Check if UFW is already active
    if ufw status 2>/dev/null | grep -q "Status: active"; then
        log_warn "UFW is already active. Updating rules without full reset."
        log_warn "To completely reset UFW, run: sudo ufw --force reset"

        # Ensure our SSH rule exists
        ufw allow "$SSH_PORT"/tcp 2>/dev/null || true
        ufw limit "$SSH_PORT"/tcp comment 'ssh rate limited' 2>/dev/null || true
    else
        log_info "Configuring UFW for first time..."

        # Reset UFW to default state
        ufw --force reset

        # Set default policies
        ufw default deny incoming
        ufw default allow outgoing

        # Allow SSH on custom port with rate limiting
        ufw allow "$SSH_PORT"/tcp
        ufw limit "$SSH_PORT"/tcp comment 'ssh rate limited'

        # Enable UFW
        echo "y" | ufw enable
    fi

    ufw status verbose

    LAST_STEP=5
    save_progress 5
    log_info "UFW firewall configured."
fi

# ============================================================================
# STEP 6: POSTFIX MAIL SERVER
# ============================================================================
if [ $START_FROM_STEP -le 6 ]; then
    log_info "Step 6/$TOTAL_STEPS: Configuring Postfix mail server..."

    # Pre-configure Postfix for non-interactive installation
    export DEBIAN_FRONTEND=noninteractive
    debconf-set-selections << EOF
postfix postfix/mailname string $MAIL_HOSTNAME
postfix postfix/main_mailer_type string 'Internet Site'
EOF

    # Install Postfix and mailutils
    apt install -y postfix mailutils

    # Set system hostname
    log_info "Setting system hostname to $MAIL_HOSTNAME..."
    hostnamectl set-hostname "$MAIL_HOSTNAME"

    # Set /etc/mailname
    log_info "Configuring /etc/mailname..."
    backup_file /etc/mailname
    echo "$MAIL_HOSTNAME" > /etc/mailname

    # Update /etc/hosts - preserve additional entries
    log_info "Updating /etc/hosts..."
    backup_file /etc/hosts
    if grep -q "^127.0.1.1" /etc/hosts; then
        # Extract short hostname from FQDN
        SHORT_HOSTNAME="${MAIL_HOSTNAME%%.*}"
        sed -i "s/^127.0.1.1[[:space:]].*/127.0.1.1 $MAIL_HOSTNAME $SHORT_HOSTNAME/" /etc/hosts
    else
        echo "127.0.1.1 $MAIL_HOSTNAME" >> /etc/hosts
    fi

    # Backup Postfix main.cf
    backup_file /etc/postfix/main.cf

    # Configure Postfix using postconf for safe updates
    log_info "Configuring Postfix main.cf..."
    postconf -e "myhostname = $MAIL_HOSTNAME"
    postconf -e "myorigin = /etc/mailname"
    postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost"
    postconf -e "mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128"
    postconf -e "inet_interfaces = loopback-only"
    postconf -e "inet_protocols = all"

    # Security settings
    postconf -e "smtpd_banner = \$myhostname ESMTP"
    postconf -e "disable_vrfy_command = yes"
    postconf -e "smtpd_helo_required = yes"
    postconf -e "smtpd_recipient_restrictions = permit_mynetworks, reject_unauth_destination"
    postconf -e "smtpd_relay_restrictions = permit_mynetworks, reject_unauth_destination"

    # Use Maildir format
    postconf -e "home_mailbox = Maildir/"

    # Mail size limit (10MB)
    postconf -e "message_size_limit = 10485760"
    postconf -e "mailbox_size_limit = 0"

    # Configure mail aliases to forward root mail to new user
    log_info "Configuring mail aliases..."
    backup_file /etc/aliases

    if ! grep -q "^root:" /etc/aliases; then
        echo "root: $NEW_USER" >> /etc/aliases
    else
        sed -i "s/^root:.*/root: $NEW_USER/" /etc/aliases
    fi

    # Update aliases database
    newaliases

    # Validate Postfix configuration
    log_info "Validating Postfix configuration..."
    if postfix check; then
        log_info "Postfix configuration is valid"
    else
        log_error "Postfix configuration validation failed"
        exit 1
    fi

    # Restart Postfix service
    systemctl restart postfix

    # Verify Postfix is running
    if systemctl is-active --quiet postfix; then
        systemctl enable postfix
        log_info "Postfix mail server configured and running"
        log_info "Mail server configured for local delivery only (secure default)"
        log_info "Root mail forwarded to: $NEW_USER"
        log_info ""
        log_info "Test mail delivery with:"
        log_info "  echo 'Test message' | mail -s 'Test Subject' root"
        log_info "  Check mail: sudo -u $NEW_USER mail"

        LAST_STEP=6
        save_progress 6
    else
        log_error "Postfix failed to start. Check logs: journalctl -u postfix"
        exit 1
    fi
fi

# ============================================================================
# STEP 7: DOCKER + UFW-DOCKER (OPTIONAL)
# ============================================================================
if [ $START_FROM_STEP -le 7 ]; then
    log_info "Step 7/$TOTAL_STEPS: Docker + ufw-docker (optional)..."

    INSTALL_DOCKER=false

    if [ -t 0 ]; then
        read -p "Do you want to install Docker and ufw-docker? [y/N] " -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            INSTALL_DOCKER=true
        fi
    else
        log_info "Non-interactive mode: skipping Docker installation."
    fi

    if [ "$INSTALL_DOCKER" = true ]; then
        log_info "Installing Docker Engine using official convenience script..."

        # Download Docker installer first, then execute
        DOCKER_INSTALLER=$(mktemp)
        if curl -fsSL https://get.docker.com -o "$DOCKER_INSTALLER"; then
            sh "$DOCKER_INSTALLER"
            rm -f "$DOCKER_INSTALLER"
            log_info "Docker Engine installed successfully."
        else
            log_error "Failed to download Docker installer"
            rm -f "$DOCKER_INSTALLER"
            exit 1
        fi

        # Add user to docker group
        usermod -aG docker "$NEW_USER"
        log_info "User '$NEW_USER' added to docker group."

        # Install ufw-docker
        log_info "Installing ufw-docker..."
        UFW_DOCKER_SCRIPT=$(mktemp)
        if curl -fsSL https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker -o "$UFW_DOCKER_SCRIPT"; then
            install -m 755 "$UFW_DOCKER_SCRIPT" /usr/local/bin/ufw-docker
            rm -f "$UFW_DOCKER_SCRIPT"

            # Run ufw-docker install
            /usr/local/bin/ufw-docker install

            # Restart UFW
            systemctl restart ufw

            log_info "ufw-docker installed and configured."
            log_info ""
            log_info "Usage example:"
            log_info "  # Allow external access to a container's port:"
            log_info "  sudo ufw-docker allow <container-name> 80"
            log_info ""
            log_info "  # Delete a rule:"
            log_info "  sudo ufw-docker delete allow <container-name> 80"
            log_info ""
        else
            log_error "Failed to download ufw-docker"
            rm -f "$UFW_DOCKER_SCRIPT"
        fi
    else
        log_info "Skipping Docker installation."
    fi

    LAST_STEP=7
    save_progress 7
fi

# ============================================================================
# STEP 8: AUDITD
# ============================================================================
if [ $START_FROM_STEP -le 8 ]; then
    log_info "Step 8/$TOTAL_STEPS: Installing and configuring auditd..."

    apt install -y auditd audispd-plugins

    backup_file /etc/audit/rules.d/custom.rules

    # Add custom audit rules
    cat > /etc/audit/rules.d/custom.rules << 'EOF'
# Audit rules - Comprehensive monitoring
# ============================================================================
# AUTHENTICATION & USER MANAGEMENT
# ============================================================================
-w /var/log/auth.log -p wa -k auth_log
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/gshadow -p wa -k gshadow_changes
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes
-w /etc/security/faillock.conf -p wa -k pam_changes
-w /etc/pam.d/ -p wa -k pam_changes

# ============================================================================
# SSH & REMOTE ACCESS
# ============================================================================
-w /etc/ssh/sshd_config -p wa -k sshd_config_changes
-w /etc/ssh/sshd_config.d/ -p wa -k sshd_config_changes

# ============================================================================
# FIREWALL & NETWORK SECURITY
# ============================================================================
-w /etc/ufw/ -p wa -k firewall_changes
-w /etc/default/ufw -p wa -k firewall_changes
-w /etc/crowdsec/ -p wa -k crowdsec_changes
-w /sbin/iptables -p x -k firewall_commands
-w /sbin/ip6tables -p x -k firewall_commands
-w /sbin/ufw -p x -k firewall_commands

# ============================================================================
# MAIL SERVER
# ============================================================================
-w /etc/postfix/ -p wa -k mail_config
-w /etc/aliases -p wa -k mail_config

# ============================================================================
# APPARMOR
# ============================================================================
-w /etc/apparmor/ -p wa -k apparmor_changes
-w /etc/apparmor.d/ -p wa -k apparmor_changes

# ============================================================================
# SYSTEM INTEGRITY
# ============================================================================
-w /etc/aide/aide.conf -p wa -k aide_changes
-w /var/lib/aide/ -p wa -k aide_changes

# ============================================================================
# CRON & SCHEDULED TASKS
# ============================================================================
-w /etc/cron.allow -p wa -k cron_changes
-w /etc/cron.deny -p wa -k cron_changes
-w /etc/cron.d/ -p wa -k cron_changes
-w /etc/cron.daily/ -p wa -k cron_changes
-w /etc/cron.hourly/ -p wa -k cron_changes
-w /etc/cron.monthly/ -p wa -k cron_changes
-w /etc/cron.weekly/ -p wa -k cron_changes
-w /etc/crontab -p wa -k cron_changes
-w /var/spool/cron/ -p wa -k cron_changes

# ============================================================================
# SYSTEM CONFIGURATION
# ============================================================================
-w /etc/sysctl.conf -p wa -k sysctl_changes
-w /etc/sysctl.d/ -p wa -k sysctl_changes
-w /etc/hosts -p wa -k network_config
-w /etc/hostname -p wa -k network_config
-w /etc/network/ -p wa -k network_config
-w /etc/fstab -p wa -k filesystem_changes

# ============================================================================
# KERNEL MODULES
# ============================================================================
-w /sbin/insmod -p x -k kernel_modules
-w /sbin/rmmod -p x -k kernel_modules
-w /sbin/modprobe -p x -k kernel_modules
-a always,exit -F arch=b64 -S init_module,delete_module -k kernel_modules
-a always,exit -F arch=b32 -S init_module,delete_module -k kernel_modules

# ============================================================================
# FILE DELETION & PERMISSION CHANGES
# ============================================================================
-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=-1 -k file_deletion
-a always,exit -F arch=b32 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=-1 -k file_deletion
-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=-1 -k perm_mod
-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=-1 -k perm_mod
-a always,exit -F arch=b64 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=-1 -k perm_mod
-a always,exit -F arch=b32 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=-1 -k perm_mod
-a always,exit -F arch=b64 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=-1 -k perm_mod
-a always,exit -F arch=b32 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=-1 -k perm_mod

# ============================================================================
# PRIVILEGE ESCALATION
# ============================================================================
-a always,exit -F arch=b64 -S setuid,setreuid,setresuid -F auid>=1000 -F auid!=-1 -k privilege_escalation
-a always,exit -F arch=b32 -S setuid,setreuid,setresuid -F auid>=1000 -F auid!=-1 -k privilege_escalation
-a always,exit -F arch=b64 -S setgid,setregid,setresgid -F auid>=1000 -F auid!=-1 -k privilege_escalation
-a always,exit -F arch=b32 -S setgid,setregid,setresgid -F auid>=1000 -F auid!=-1 -k privilege_escalation

# ============================================================================
# SYSTEM CALLS
# ============================================================================
-a always,exit -F arch=b64 -S adjtimex,settimeofday -k time_change
-a always,exit -F arch=b32 -S adjtimex,settimeofday,stime -k time_change
-a always,exit -F arch=b64 -S sethostname,setdomainname -k network_modifications
-a always,exit -F arch=b32 -S sethostname,setdomainname -k network_modifications

# ============================================================================
# EXECUTABLE MONITORING
# ============================================================================
-w /usr/bin/sudo -p x -k sudo_execution
-w /usr/bin/su -p x -k su_execution
-w /bin/su -p x -k su_execution

# Make configuration immutable (optional - uncomment to enable)
# -e 2
EOF

    # Reload audit rules properly
    if command -v augenrules >/dev/null 2>&1; then
        if augenrules --load >/dev/null 2>&1; then
            log_info "Audit rules reloaded"
        else
            log_warn "Failed to load audit rules - attempting auditd restart"
            service auditd restart 2>/dev/null || systemctl restart auditd 2>/dev/null || log_warn "Could not reload audit rules"
        fi
    else
        systemctl restart auditd
    fi

    if systemctl is-active --quiet auditd; then
        log_info "Auditd configured with custom rules."
    else
        log_warn "Auditd may not have started properly. Check: systemctl status auditd"
    fi

    LAST_STEP=8
    save_progress 8
fi

# ============================================================================
# STEP 9: LYNIS
# ============================================================================
if [ $START_FROM_STEP -le 9 ]; then
    log_info "Step 9/$TOTAL_STEPS: Installing Lynis security audit tool..."

    apt install -y lynis

    LAST_STEP=9
    save_progress 9
    log_info "Lynis installed. Run 'sudo lynis audit system' to perform security audit."
fi

# ============================================================================
# STEP 10: RKHUNTER
# ============================================================================
if [ $START_FROM_STEP -le 10 ]; then
    log_info "Step 10/$TOTAL_STEPS: Installing and configuring rkhunter..."

    apt install -y rkhunter

    backup_file /etc/rkhunter.conf

    # Fix rkhunter configuration for Ubuntu 24.04
    sed -i 's|^WEB_CMD=.*|WEB_CMD=""|' /etc/rkhunter.conf
    sed -i 's|^MIRRORS_MODE=.*|MIRRORS_MODE=0|' /etc/rkhunter.conf
    sed -i 's|^ALLOWHIDDENDIR=.*|ALLOWHIDDENDIR=/dev/.lxc|' /etc/rkhunter.conf
    sed -i 's|^#ALLOWHIDDENDIR=/dev/.udev|ALLOWHIDDENDIR=/dev/.udev|' /etc/rkhunter.conf

    # Update rkhunter database with selective warning suppression
    rkhunter --update 2>&1 | grep -v "Warning: Invalid WEB_CMD" || true
    rkhunter --propupd 2>&1 | grep -v "Warning: Invalid WEB_CMD" || true

    LAST_STEP=10
    save_progress 10
    log_info "Rkhunter installed and configured."
fi

# ============================================================================
# STEP 11: SECURE SHARED MEMORY
# ============================================================================
if [ $START_FROM_STEP -le 11 ]; then
    log_info "Step 11/$TOTAL_STEPS: Securing shared memory..."

    if ! grep -q "tmpfs.*\/run\/shm" /etc/fstab; then
        backup_file /etc/fstab
        echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
        log_info "Shared memory secured in /etc/fstab"
    else
        log_warn "Shared memory entry already exists in /etc/fstab"
    fi

    LAST_STEP=11
    save_progress 11
fi

# ============================================================================
# STEP 12: PERSISTENT LOGGING
# ============================================================================
if [ $START_FROM_STEP -le 12 ]; then
    log_info "Step 12/$TOTAL_STEPS: Enabling persistent journald logging..."

    mkdir -p /var/log/journal
    systemd-tmpfiles --create --prefix /var/log/journal

    backup_file /etc/systemd/journald.conf.d/persistent.conf

    cat > /etc/systemd/journald.conf.d/persistent.conf << 'EOF'
# Journald configuration
[Journal]
Storage=persistent
Compress=yes
SystemMaxUse=500M
SystemMaxFileSize=100M
EOF

    systemctl restart systemd-journald

    LAST_STEP=12
    save_progress 12
    log_info "Persistent logging enabled."
fi

# ============================================================================
# STEP 13: AIDE
# ============================================================================
if [ $START_FROM_STEP -le 13 ]; then
    log_info "Step 13/$TOTAL_STEPS: Installing AIDE (this may take several minutes)..."

    apt install -y aide aide-common

    # Only initialize if database doesn't exist
    if [ ! -f /var/lib/aide/aide.db ] && [ ! -f /var/lib/aide/aide.db.gz ]; then
        # Add AIDE progress indicator
        log_info "Initializing AIDE database (this may take 10-15 minutes)..."
        log_info "Progress indicator: A dot will appear every 10 seconds..."

        aideinit &
        AIDE_PID=$!

        # Show progress while AIDE is initializing
        while kill -0 $AIDE_PID 2>/dev/null; do
            echo -n "."
            sleep 10
        done
        echo ""

        wait $AIDE_PID

        # Move database to correct location
        if [ -f /var/lib/aide/aide.db.new ]; then
            mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        fi
        log_info "AIDE database initialized."
    else
        log_info "AIDE database already exists. Skipping initialization."
    fi

    # Set up weekly AIDE checks with PATH
    cat > /etc/cron.weekly/aide-check << 'EOF'
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

/usr/bin/aide --check | mail -s "AIDE Report for $(hostname)" root
EOF
    chmod +x /etc/cron.weekly/aide-check

    LAST_STEP=13
    save_progress 13
    log_info "AIDE configured."
fi

# ============================================================================
# STEP 14: ADDITIONAL SECURITY
# ============================================================================
if [ $START_FROM_STEP -le 14 ]; then
    log_info "Step 14/$TOTAL_STEPS: Applying additional security settings..."

    # Disable core dumps
    cat > /etc/security/limits.d/disable-coredumps.conf << 'EOF'
* hard core 0
EOF

    backup_file /etc/sysctl.d/99-security.conf

    # Kernel hardening with enhanced IPv6 and Docker support
    cat > /etc/sysctl.d/99-security.conf << 'EOF'
# Kernel hardening
# =============================================================================
# IPv4 SECURITY
# =============================================================================
# Enable IP forwarding for site-to-site network and Docker
net.ipv4.ip_forward = 1

# Disable source packet routing
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# Enable IP spoofing protection (loose mode for routing/VPN)
# rp_filter = 2 allows asymmetric routing needed for site-to-site networks
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2

# Ignore ICMP ping requests (set to 1 to disable ping)
net.ipv4.icmp_echo_ignore_all = 0

# Ignore broadcast pings
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Enable TCP SYN cookies (SYN flood protection)
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096

# Log martian packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore source-routed packets
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# =============================================================================
# IPv6 SECURITY
# =============================================================================
# Keep IPv6 enabled and allow forwarding for site-to-site network
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.all.forwarding = 1

# Disable IPv6 router advertisements
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# Disable IPv6 redirects
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Disable IPv6 source routing
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# =============================================================================
# KERNEL HARDENING
# =============================================================================
# Restrict kernel pointer exposure
kernel.kptr_restrict = 2

# Restrict access to kernel logs
kernel.dmesg_restrict = 1

# Restrict kernel performance events
kernel.perf_event_paranoid = 3

# Disable kexec (prevents malicious kernel loading)
kernel.kexec_load_disabled = 1

# Enable ASLR (Address Space Layout Randomization)
kernel.randomize_va_space = 2

# Restrict ptrace scope (prevents process injection)
kernel.yama.ptrace_scope = 2

# =============================================================================
# FILESYSTEM HARDENING
# =============================================================================
# Restrict SUID core dumps
fs.suid_dumpable = 0

# Increase inotify limits for Docker
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512

# =============================================================================
# NETWORK HARDENING
# =============================================================================
# Increase connection tracking for Docker
net.netfilter.nf_conntrack_max = 262144

# TCP hardening
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 1

# Increase network buffer sizes for Docker
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# =============================================================================
# ROUTING & VPN OPTIMIZATIONS
# =============================================================================
# Enable proxy ARP for site-to-site networking
net.ipv4.conf.all.proxy_arp = 0

# Increase routing table size for complex network topologies
net.ipv4.route.max_size = 2147483647
net.ipv6.route.max_size = 2147483647

# Allow local port range for outgoing connections
net.ipv4.ip_local_port_range = 32768 60999

# Enable TCP Fast Open for better performance
net.ipv4.tcp_fastopen = 3

# Optimize for routing workloads
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1

# Enable IPv6 optimizations
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
EOF

    # Don't suppress sysctl errors
    if sysctl -p /etc/sysctl.d/99-security.conf; then
        log_info "Sysctl settings applied successfully"
    else
        log_warn "Some sysctl settings failed to apply. Check: dmesg | tail"
    fi

    LAST_STEP=14
    save_progress 14
fi

# ============================================================================
# STEP 15: APPARMOR DOCKER SECURITY
# ============================================================================
if [ $START_FROM_STEP -le 15 ]; then
    # Use check_docker_installed function
    if check_docker_installed; then
        log_info "Step 15/$TOTAL_STEPS: Configuring AppArmor for Docker..."

        # Install AppArmor profiles
        apt install -y apparmor apparmor-utils apparmor-profiles apparmor-profiles-extra

        # Enable AppArmor
        systemctl enable apparmor
        systemctl start apparmor || true

        # Create Docker AppArmor profile with userns support (Ubuntu 24.04 requirement)
    cat > /etc/apparmor.d/docker-default << 'EOF'
#include <tunables/global>

profile docker-default flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  # Allow unprivileged user namespaces (required for Ubuntu 24.04)
  userns,

  # Network access
  network inet,
  network inet6,

  # File access
  file,
  umount,

  # Capabilities needed by containers
  capability chown,
  capability dac_override,
  capability dac_read_search,
  capability fowner,
  capability fsetid,
  capability kill,
  capability setgid,
  capability setuid,
  capability setpcap,
  capability net_bind_service,
  capability net_raw,
  capability sys_chroot,
  capability mknod,
  capability audit_write,
  capability setfcap,

  # Deny dangerous capabilities
  deny capability sys_admin,
  deny capability sys_module,
  deny capability sys_boot,

  # Process control
  signal (send) peer=unconfined,
  signal (send) peer=docker-default,
  signal (receive) peer=docker-default,
  ptrace (readby, tracedby) peer=docker-default,

  # Suppress noisy denials
  deny /sys/firmware/efi/efivars/** rw,
  deny /sys/kernel/security/** rw,
}
EOF

    # Don't suppress AppArmor error output
    APPARMOR_ERR=$(mktemp)
    if apparmor_parser -r /etc/apparmor.d/docker-default 2>"$APPARMOR_ERR"; then
        log_info "AppArmor Docker profile loaded successfully"
    else
        log_warn "AppArmor profile load failed - may need reboot. Error:"
        cat "$APPARMOR_ERR"
    fi
    rm -f "$APPARMOR_ERR"

        # Configure Docker to use AppArmor
        mkdir -p /etc/docker

        # Handle daemon.json better
        if [ -f /etc/docker/daemon.json ]; then
            backup_file /etc/docker/daemon.json
            log_warn "Existing Docker daemon.json found and backed up."
            log_warn "New configuration written. Manual merge may be required."
            log_warn "Check: /etc/docker/daemon.json.backup-*"
        fi

        cat > /etc/docker/daemon.json << EOF
{
  "icc": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
EOF

        # Restart Docker
        if systemctl restart docker; then
            log_info "Docker restarted successfully"
        else
            log_warn "Docker restart failed. Check: journalctl -u docker"
        fi

        # Verify AppArmor is active
        if aa-status 2>/dev/null | grep -q docker-default; then
            log_info "AppArmor Docker profile loaded successfully"
        else
            log_warn "AppArmor profile may not be active - check with: aa-status"
        fi

        log_info "Docker security configured: AppArmor + no-new-privileges"
    else
        log_info "Step 15/$TOTAL_STEPS: Skipping AppArmor Docker security (Docker not installed)"
    fi

    LAST_STEP=15
    save_progress 15
fi

# ============================================================================
# STEP 16: DOCKER RUNTIME SECURITY
# ============================================================================
if [ $START_FROM_STEP -le 16 ]; then
    # Use check_docker_installed function
    if check_docker_installed; then
        log_info "Step 16/$TOTAL_STEPS: Configuring Docker runtime security..."

        # Create Docker audit rules directory if needed
        mkdir -p /etc/audit/rules.d

        # Create Docker audit rules
        cat > /etc/audit/rules.d/docker.rules << 'EOF'
# Docker daemon monitoring
-w /usr/bin/docker -p wa -k docker
-w /var/lib/docker -p wa -k docker
-w /etc/docker -p wa -k docker
-w /lib/systemd/system/docker.service -p wa -k docker
-w /lib/systemd/system/docker.socket -p wa -k docker
-w /etc/docker/daemon.json -p wa -k docker
-w /usr/bin/dockerd -p wa -k docker

# Container runtime monitoring
-w /usr/bin/containerd -p wa -k docker
-w /usr/bin/runc -p wa -k docker
EOF

        # Reload audit rules if auditd is installed
        if command -v augenrules >/dev/null 2>&1; then
            if augenrules --load 2>/dev/null; then
                log_info "Docker audit rules loaded successfully"
            else
                log_warn "Failed to load audit rules - attempting auditd restart"
                service auditd restart 2>/dev/null || systemctl restart auditd 2>/dev/null || log_warn "Could not reload audit rules"
            fi
        else
            log_warn "auditd not installed - Docker audit rules created but not loaded"
        fi

        # Create script to check for privileged containers (security risk)
        cat > /usr/local/bin/check-docker-security << 'EOF'
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

# Check for security issues in running containers

echo "=== Docker Security Check - $(date) ==="
echo ""

# Check if Docker is running
if ! systemctl is-active --quiet docker; then
    echo "Docker is not running"
    exit 1
fi

# Check for privileged containers
echo "1. Privileged containers (SECURITY RISK):"
if docker ps --quiet --all 2>/dev/null | grep -q .; then
    docker ps --quiet --all | xargs docker inspect --format '{{ .Name }}: Privileged={{ .HostConfig.Privileged }}' 2>/dev/null | grep "Privileged=true" || echo "   None found (good)"
else
    echo "   No containers found"
fi
echo ""

# Check for containers with host network
echo "2. Containers using host network:"
if docker ps --quiet --all 2>/dev/null | grep -q .; then
    docker ps --quiet --all | xargs docker inspect --format '{{ .Name }}: NetworkMode={{ .HostConfig.NetworkMode }}' 2>/dev/null | grep "NetworkMode=host" || echo "   None found (good)"
else
    echo "   No containers found"
fi
echo ""

# Check for containers with sensitive mounts
echo "3. Containers with sensitive host mounts:"
if docker ps --quiet --all 2>/dev/null | grep -q .; then
    docker ps --quiet --all | xargs docker inspect --format '{{ .Name }}: {{ range .Mounts }}{{ .Source }} {{ end }}' 2>/dev/null | grep -E '/(etc|root|boot|sys|proc)\b' || echo "   None found (good)"
else
    echo "   No containers found"
fi
echo ""

# Check for containers running as root - safe iteration
echo "4. Containers running as root (check manually):"
if docker ps --quiet 2>/dev/null | grep -q .; then
    docker ps --quiet 2>/dev/null | while read -r container; do
        user=$(docker inspect --format '{{ .Config.User }}' "$container" 2>/dev/null)
        name=$(docker inspect --format '{{ .Name }}' "$container" 2>/dev/null | sed 's/^\///')
        if [ -z "$user" ]; then
            echo "   $name: Running as root (default)"
        else
            echo "   $name: User=$user"
        fi
    done
else
    echo "   No running containers"
fi
echo ""

# Check Docker daemon configuration
echo "5. Docker daemon security settings:"
docker info --format 'Security Options: {{ .SecurityOptions }}' 2>/dev/null || echo "   Unable to check"
echo ""

echo "=== Security check complete ==="
EOF

        chmod +x /usr/local/bin/check-docker-security

        # Create weekly cron job with PATH
        cat > /etc/cron.weekly/docker-security-check << 'EOF'
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

/usr/local/bin/check-docker-security > /var/log/docker-security-check.log 2>&1
EOF

        chmod +x /etc/cron.weekly/docker-security-check

        log_info "Docker runtime security configured."
        log_info "Run 'check-docker-security' to audit container security."
    else
        log_info "Step 16/$TOTAL_STEPS: Skipping Docker runtime security (Docker not installed)"
    fi

    LAST_STEP=16
    save_progress 16
fi

# ============================================================================
# STEP 17: SECURE TMPFS
# ============================================================================
if [ $START_FROM_STEP -le 17 ]; then
    log_info "Step 17/$TOTAL_STEPS: Configuring temporary filesystems..."

    backup_file /etc/fstab

    # Calculate tmpfs size dynamically (25% of RAM or 2GB minimum)
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TMP_SIZE=$(( TOTAL_RAM_KB / 4 / 1024 ))  # 25% in MB
    [ $TMP_SIZE -lt 2048 ] && TMP_SIZE=2048  # Minimum 2GB
    log_info "Calculated tmpfs size: ${TMP_SIZE}M (25% of RAM, minimum 2GB)"

    # Add tmpfs entries if not present
    if ! grep -q "tmpfs.*\/tmp" /etc/fstab; then
        echo "tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=${TMP_SIZE}M 0 0" >> /etc/fstab
        log_info "Added /tmp tmpfs entry"
    else
        log_warn "/tmp tmpfs entry already exists in fstab"
    fi

    if ! grep -q "\/tmp.*\/var\/tmp" /etc/fstab; then
        echo "/tmp /var/tmp none rw,noexec,nosuid,nodev,bind 0 0" >> /etc/fstab
        log_info "Bound /var/tmp to /tmp"
    else
        log_warn "/var/tmp bind entry already exists in fstab"
    fi

    # Create APT workaround for noexec /tmp
    mkdir -p /etc/apt/apt.conf.d
    cat > /etc/apt/apt.conf.d/50remount-tmp << 'EOF'
DPkg::Pre-Install-Pkgs {
    "mount -o remount,exec /tmp";
};
DPkg::Post-Invoke {
    "mount -o remount /tmp";
};
EOF

    # Docker-specific tmp directory (if Docker installed)
    if check_docker_installed; then
        if [ ! -d /var/lib/docker/tmp ]; then
            mkdir -p /var/lib/docker/tmp
            log_info "Created Docker-specific tmp directory"
        fi

        # Set ownership and permissions
        if getent group docker > /dev/null 2>&1; then
            chown root:docker /var/lib/docker/tmp
        else
            chown root:root /var/lib/docker/tmp
        fi
        chmod 1770 /var/lib/docker/tmp

        log_warn "Set DOCKER_TMPDIR=/var/lib/docker/tmp if Docker builds fail"
    fi

    LAST_STEP=17
    save_progress 17
    log_info "Tmpfs configured (reboot required to apply)."
fi

# ============================================================================
# STEP 18: PAM SECURITY
# ============================================================================
if [ $START_FROM_STEP -le 18 ]; then
    log_info "Step 18/$TOTAL_STEPS: Configuring PAM account lockout..."

    # Configure faillock for account lockout
    cat > /etc/security/faillock.conf << 'EOF'
# Account lockout policy
# Lock account after 5 failed attempts
deny = 5
# Unlock after 15 minutes (900 seconds)
unlock_time = 900
# Track failures over 15 minutes
fail_interval = 900
# Also apply to root (be careful!)
even_deny_root
# Root unlocks after 10 minutes
root_unlock_time = 600
# Enable audit logging
audit
EOF

    LAST_STEP=18
    save_progress 18
    log_info "PAM account lockout configured."
    log_info "Unlock locked account: faillock --user USERNAME --reset"
fi

# ============================================================================
# STEP 19: KERNEL MODULE BLACKLIST
# ============================================================================
if [ $START_FROM_STEP -le 19 ]; then
    log_info "Step 19/$TOTAL_STEPS: Blacklisting unnecessary kernel modules..."

    # Disable USB storage (VPS doesn't need it)
    cat > /etc/modprobe.d/blacklist-usb.conf << 'EOF'
# Disable USB storage to prevent data exfiltration
blacklist usb_storage
blacklist uas
install usb_storage /bin/true
install uas /bin/true
EOF

    # Disable uncommon network protocols
    cat > /etc/modprobe.d/blacklist-network.conf << 'EOF'
# Disable uncommon network protocols
blacklist dccp
blacklist sctp
blacklist rds
blacklist tipc
blacklist bluetooth
blacklist btusb
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
install bluetooth /bin/true
install btusb /bin/true
EOF

    # Disable uncommon filesystems
    cat > /etc/modprobe.d/blacklist-filesystems.conf << 'EOF'
# Disable uncommon filesystems
blacklist cramfs
blacklist freevxfs
blacklist jffs2
blacklist hfs
blacklist hfsplus
blacklist udf
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install udf /bin/true
EOF

    # Update initramfs
    update-initramfs -u

    LAST_STEP=19
    save_progress 19
    log_info "Kernel modules blacklisted (reboot required to apply)."
fi

# ============================================================================
# STEP 20: DNS SECURITY
# ============================================================================
if [ $START_FROM_STEP -le 20 ]; then
    log_info "Step 20/$TOTAL_STEPS: Configuring DNS security (DNSSEC + DNS-over-TLS)..."

    # Create systemd-resolved configuration directory
    mkdir -p /etc/systemd/resolved.conf.d

    # Configure systemd-resolved
    cat > /etc/systemd/resolved.conf.d/dns-security.conf << 'EOF'
[Resolve]
# Use Cloudflare DNS with DoT support
DNS=1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001
FallbackDNS=8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844
Domains=~.
# Enable DNSSEC validation
DNSSEC=yes
# Enable DNS-over-TLS (opportunistic - fallback if server doesn't support)
DNSOverTLS=opportunistic
# Cache DNS queries
Cache=yes
# Use stub resolver
DNSStubListener=yes
EOF

    # Restart systemd-resolved
    systemctl restart systemd-resolved

    # Verify configuration
    sleep 2
    if resolvectl status 2>/dev/null | grep -q "DNSSEC setting: yes"; then
        log_info "DNSSEC enabled successfully"
    else
        log_warn "DNSSEC may not be active - check with: resolvectl status"
    fi

    LAST_STEP=20
    save_progress 20
    log_info "DNS security configured with DNSSEC and DNS-over-TLS."
fi

# ============================================================================
# STEP 21: AUTOMATED SECURITY AUDITS
# ============================================================================
if [ $START_FROM_STEP -le 21 ]; then
    log_info "Step 21/$TOTAL_STEPS: Setting up automated security audits..."

    # Lynis should already be installed from Step 9

    # Create weekly Lynis audit script with PATH
    cat > /usr/local/bin/weekly-security-audit << 'EOF'
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

# Weekly automated security audit

REPORT_DIR="/var/log/security-audits"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="$REPORT_DIR/lynis-$TIMESTAMP.log"

mkdir -p "$REPORT_DIR"

# Run Lynis audit
lynis audit system --quick --quiet --log-file "$REPORT_FILE"

# Extract warnings and suggestions
WARNINGS=$(grep "Warning" "$REPORT_FILE" | wc -l)
SUGGESTIONS=$(grep "Suggestion" "$REPORT_FILE" | wc -l)
SCORE=$(grep "Hardening index" "$REPORT_FILE" | awk '{print $4}' | head -1)

# Create summary
cat > "$REPORT_DIR/latest-summary.txt" << SUMMARY
Security Audit Summary - $(date)
=====================================
Hardening Score: $SCORE
Warnings: $WARNINGS
Suggestions: $SUGGESTIONS

Full report: $REPORT_FILE

Top Issues:
$(grep -E "Warning|Suggestion" "$REPORT_FILE" | head -10)

Run 'lynis show details TEST-ID' for more info.
SUMMARY

# Keep only last 10 reports
ls -t "$REPORT_DIR"/lynis-*.log 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null

echo "Security audit completed. Report: $REPORT_FILE"
cat "$REPORT_DIR/latest-summary.txt"
EOF

    chmod +x /usr/local/bin/weekly-security-audit

    # Schedule weekly audit
    cat > /etc/cron.weekly/security-audit << 'EOF'
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

/usr/local/bin/weekly-security-audit
EOF

    chmod +x /etc/cron.weekly/security-audit

    LAST_STEP=21
    save_progress 21
    log_info "Automated security audits configured."
    log_info "Test manually: weekly-security-audit"
fi

# ============================================================================
# STEP 22: LOG MONITORING
# ============================================================================
if [ $START_FROM_STEP -le 22 ]; then
    log_info "Step 22/$TOTAL_STEPS: Configuring log monitoring and alerts..."

    # Create daily log monitoring script with PATH
    cat > /usr/local/bin/daily-log-check << 'EOF'
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

# Daily security log check

ALERT_FILE="/tmp/security-alerts.txt"
> "$ALERT_FILE"

# Check for failed SSH attempts
if [ -f /var/log/auth.log ]; then
    SSH_FAILS=$(grep "Failed password" /var/log/auth.log 2>/dev/null | tail -20)
    if [ -n "$SSH_FAILS" ]; then
        echo "=== Recent SSH Login Failures ===" >> "$ALERT_FILE"
        echo "$SSH_FAILS" >> "$ALERT_FILE"
        echo "" >> "$ALERT_FILE"
    fi

    # Check for sudo usage
    SUDO_USAGE=$(grep "sudo:" /var/log/auth.log 2>/dev/null | tail -20)
    if [ -n "$SUDO_USAGE" ]; then
        echo "=== Recent Sudo Usage ===" >> "$ALERT_FILE"
        echo "$SUDO_USAGE" >> "$ALERT_FILE"
        echo "" >> "$ALERT_FILE"
    fi
fi

# Check for Docker events
if command -v docker &> /dev/null && systemctl is-active --quiet docker; then
    DOCKER_EVENTS=$(docker events --since 24h --until 0s 2>/dev/null | grep -E "start|stop|die|kill" | tail -20)
    if [ -n "$DOCKER_EVENTS" ]; then
        echo "=== Docker Container Events (24h) ===" >> "$ALERT_FILE"
        echo "$DOCKER_EVENTS" >> "$ALERT_FILE"
        echo "" >> "$ALERT_FILE"
    fi
fi

# Check CrowdSec status
if systemctl is-active --quiet crowdsec; then
    BANNED_IPS=$(cscli decisions list 2>/dev/null | grep -v "^ID" | head -10)
    if [ -n "$BANNED_IPS" ]; then
        echo "=== CrowdSec Active Decisions ===" >> "$ALERT_FILE"
        echo "$BANNED_IPS" >> "$ALERT_FILE"
        echo "" >> "$ALERT_FILE"
    fi
fi

# Check disk usage
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "=== WARNING: Disk Usage Above 80% ===" >> "$ALERT_FILE"
    df -h >> "$ALERT_FILE"
    echo "" >> "$ALERT_FILE"
fi

# Check for unusual Docker resource usage
if command -v docker &> /dev/null && systemctl is-active --quiet docker; then
    if docker ps --quiet 2>/dev/null | grep -q .; then
        HIGH_CPU=$(docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}" 2>/dev/null | awk 'NR>1 {gsub("%","",$2); if($2+0>80) print}')
        if [ -n "$HIGH_CPU" ]; then
            echo "=== Containers with High CPU Usage ===" >> "$ALERT_FILE"
            echo "$HIGH_CPU" >> "$ALERT_FILE"
            echo "" >> "$ALERT_FILE"
        fi
    fi
fi

# Display or log alerts
if [ -s "$ALERT_FILE" ]; then
    echo "Security alerts found for $(date):"
    cat "$ALERT_FILE"
else
    echo "No security alerts for $(date)"
fi

rm -f "$ALERT_FILE"
EOF

    chmod +x /usr/local/bin/daily-log-check

    # Schedule daily check
    cat > /etc/cron.daily/security-log-check << 'EOF'
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

/usr/local/bin/daily-log-check >> /var/log/daily-security-check.log 2>&1
EOF

    chmod +x /etc/cron.daily/security-log-check

    LAST_STEP=22
    save_progress 22
    log_info "Log monitoring configured."
    log_info "Test manually: daily-log-check"
fi

# ============================================================================
# STEP 23: FILE PERMISSIONS
# ============================================================================
if [ $START_FROM_STEP -le 23 ]; then
    log_info "Step 23/$TOTAL_STEPS: Setting secure file permissions..."

    # Root directory
    chmod 700 /root

    # Critical system files
    chmod 644 /etc/passwd /etc/group
    chmod 600 /etc/shadow /etc/gshadow
    chmod 644 /etc/hosts /etc/hostname
    chmod 644 /etc/fstab

    # SSH configuration
    if [ -d /etc/ssh ]; then
        chmod 755 /etc/ssh
        find /etc/ssh -name "ssh*_key" -type f -exec chmod 600 {} \; 2>/dev/null || true
        find /etc/ssh -name "*.pub" -type f -exec chmod 644 {} \; 2>/dev/null || true
        chmod 644 /etc/ssh/sshd_config 2>/dev/null || true
        find /etc/ssh/sshd_config.d -type f -exec chmod 600 {} \; 2>/dev/null || true
    fi

    # Sudo configuration
    chmod 440 /etc/sudoers
    if [ -d /etc/sudoers.d ]; then
        chmod 750 /etc/sudoers.d
        find /etc/sudoers.d -type f -exec chmod 440 {} \; 2>/dev/null || true
    fi

    # PAM configuration
    if [ -d /etc/pam.d ]; then
        chmod 755 /etc/pam.d
        find /etc/pam.d -type f -exec chmod 644 {} \; 2>/dev/null || true
    fi
    [ -f /etc/security/faillock.conf ] && chmod 644 /etc/security/faillock.conf

    # CrowdSec configuration
    if [ -d /etc/crowdsec ]; then
        chmod 755 /etc/crowdsec
        find /etc/crowdsec -type f -exec chmod 644 {} \; 2>/dev/null || true
        find /etc/crowdsec -type d -exec chmod 755 {} \; 2>/dev/null || true
    fi

    # Firewall configuration
    if [ -d /etc/ufw ]; then
        chmod 755 /etc/ufw
        find /etc/ufw -type f -exec chmod 644 {} \; 2>/dev/null || true
    fi
    [ -f /etc/default/ufw ] && chmod 644 /etc/default/ufw

    # Postfix configuration
    if [ -d /etc/postfix ]; then
        chmod 755 /etc/postfix
        find /etc/postfix -type f -exec chmod 644 {} \; 2>/dev/null || true
    fi
    [ -f /etc/aliases ] && chmod 644 /etc/aliases

    # Audit configuration
    if [ -d /etc/audit ]; then
        chmod 750 /etc/audit
        find /etc/audit -type f -exec chmod 640 {} \; 2>/dev/null || true
    fi

    # AppArmor configuration
    if [ -d /etc/apparmor ]; then
        chmod 755 /etc/apparmor
        find /etc/apparmor -type f -exec chmod 644 {} \; 2>/dev/null || true
    fi
    if [ -d /etc/apparmor.d ]; then
        chmod 755 /etc/apparmor.d
        find /etc/apparmor.d -type f -exec chmod 644 {} \; 2>/dev/null || true
    fi

    # AIDE configuration
    if [ -d /etc/aide ]; then
        chmod 750 /etc/aide
        find /etc/aide -type f -exec chmod 640 {} \; 2>/dev/null || true
    fi

    # Cron directories
    chmod 755 /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.monthly /etc/cron.weekly 2>/dev/null || true
    chmod 644 /etc/crontab 2>/dev/null || true
    [ -f /etc/cron.allow ] && chmod 644 /etc/cron.allow
    [ -f /etc/cron.deny ] && chmod 644 /etc/cron.deny

    # Sysctl configuration
    if [ -d /etc/sysctl.d ]; then
        chmod 755 /etc/sysctl.d
        find /etc/sysctl.d -type f -exec chmod 644 {} \; 2>/dev/null || true
    fi
    [ -f /etc/sysctl.conf ] && chmod 644 /etc/sysctl.conf

    # Docker configuration (if installed)
    if check_docker_installed; then
        if [ -d /etc/docker ]; then
            chmod 755 /etc/docker
            find /etc/docker -type f -exec chmod 644 {} \; 2>/dev/null || true
            [ -f /etc/docker/daemon.json ] && chmod 644 /etc/docker/daemon.json
        fi
    fi

    # Be selective about log permissions - only remove world-read from sensitive logs
    for log in auth.log secure syslog kern.log; do
        [ -f "/var/log/$log" ] && chmod 640 "/var/log/$log" 2>/dev/null || true
    done

    LAST_STEP=23
    save_progress 23
    log_info "File permissions secured."
fi

# ============================================================================
# STEP 24: CLEANUP
# ============================================================================
if [ $START_FROM_STEP -le 24 ]; then
    log_info "Step 24/$TOTAL_STEPS: Cleaning up temporary files..."

    # Remove temporary files
    find /tmp -name "sshd-custom.*" -type f -mmin +60 -delete 2>/dev/null || true
    rm -f /var/tmp/hardening-apt-updated 2>/dev/null || true

    # Clean up old backup files older than 30 days
    find /etc -name "*.backup-*" -type f -mtime +30 -delete 2>/dev/null || true

    # Clean apt cache
    apt clean
    apt autoclean

    log_info "Cleanup completed."

    LAST_STEP=24
    save_progress 24
fi

# ============================================================================
# COMPLETION
# ============================================================================

# Clean up
rm -f "$STEP_FILE"

log_info "Server initialization completed successfully!"

# Display summary
cat << EOF

============================================================================
                  SERVER INITIALIZATION SUMMARY
============================================================================

✓ System updated and automatic security updates enabled
✓ New user '$NEW_USER' created with sudo privileges
✓ SSH configured (port: $SSH_PORT, key-only auth, root login disabled)
✓ SSH cipher restrictions applied (ChaCha20-Poly1305, AES256-GCM, etc.)
✓ CrowdSec installed and configured
✓ UFW firewall enabled
✓ Postfix mail server configured (local delivery only)
EOF

if check_docker_installed; then
    echo "✓ Docker Engine and ufw-docker installed"
fi

cat << EOF
✓ Auditd installed with custom rules (including Docker monitoring)
✓ File permissions secured
✓ Lynis security audit tool installed
✓ Rkhunter rootkit scanner installed
✓ Shared memory secured
✓ Persistent logging enabled
✓ AIDE intrusion detection initialized
✓ Kernel security settings applied (IPv6, Docker support)
✓ AppArmor configured for Docker security
✓ Tmpfs secured (/tmp, /var/tmp with noexec)
✓ PAM account lockout configured (faillock)
✓ Unnecessary kernel modules blacklisted
✓ DNS security configured (DNSSEC + DNS-over-TLS)
✓ Automated security audits configured (weekly)
✓ Log monitoring configured (daily checks)
EOF

if check_docker_installed; then
    echo "✓ Docker runtime security configured"
fi

cat << EOF

============================================================================
                      IMPORTANT NEXT STEPS
============================================================================

1. TEST SSH CONNECTION before logging out:
   ssh -p $SSH_PORT $NEW_USER@<server-ip>

2. Keep your current session open until SSH is confirmed working

3. REBOOT to apply all changes (required for tmpfs, kernel modules):
   sudo reboot

4. After reboot, verify settings:
   sudo aa-status                    # Check AppArmor profiles
   sudo resolvectl status            # Verify DNSSEC/DoT
   mount | grep tmpfs                # Verify tmpfs configuration
   sudo sysctl -a | grep ipv6        # Check kernel parameters

5. Test Postfix mail server:
   echo 'Test message' | mail -s 'Test Subject' root
   sudo -u $NEW_USER mail            # Check received mail

6. Run audits:
   sudo weekly-security-audit        # Automated Lynis audit
   sudo daily-log-check              # Check logs
   sudo rkhunter --check             # Rootkit scan
EOF

if check_docker_installed; then
    cat << EOF
   sudo check-docker-security        # Docker container audit

7. Docker tips:
   # User '$NEW_USER' needs to re-login for docker group changes

   # Check Docker daemon:
   docker info --format '{{ .SecurityOptions }}'

   # Allow external access to a container's port:
   sudo ufw-docker allow <container-name> 80

   # Run containers with security options:
   docker run --security-opt=no-new-privileges:true ...

8. Review logs:
   sudo journalctl -xe
   sudo tail -f /var/log/auth.log
   sudo cat $PROGRESS_FILE
   sudo cat /var/log/daily-log-check.log

9. Unlock locked accounts if needed:
   sudo faillock --user USERNAME --reset
EOF
else
    cat << EOF

7. Review logs:
   sudo journalctl -xe
   sudo tail -f /var/log/auth.log
   sudo cat $PROGRESS_FILE
   sudo cat /var/log/daily-log-check.log

8. Unlock locked accounts if needed:
   sudo faillock --user USERNAME --reset
EOF
fi

cat << EOF

============================================================================

Log file: $PROGRESS_FILE

============================================================================

EOF
