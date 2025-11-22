# Ubuntu Server Init Script - Development Guide

Development reference for modifying and extending init.sh.

## Table of Contents
- [Architecture](#architecture)
- [Adding New Steps](#adding-new-steps)
- [Code Patterns](#code-patterns)
- [Error Handling](#error-handling)
- [Testing](#testing)
- [Common Pitfalls](#common-pitfalls)

## Architecture

### File Structure
```
init.sh
├── Configuration (1-40)
├── Constants (42-88)
├── Logging (116-133)
├── Utilities (135-267)
├── Arguments (299-344)
├── Pre-flight (346-393)
├── STEPS 1-24 (395-2160)
└── Summary (2162-2370)
```

### Key Components

Constants:
```bash
readonly PROGRESS_FILE="/var/log/server-init-progress.log"
readonly STEP_FILE="/var/tmp/server-init-step"
readonly LOCK_FILE="/var/lock/server-init-script.lock"
readonly TOTAL_STEPS=24  # UPDATE when adding steps
```

Step Names Array:
```bash
declare -a STEP_NAMES=(
    ""
    "System Updates"
    "Create New User"
    # Add new step names here
)
```

Global Variables:
```bash
LAST_STEP=0           # Current step executing
START_FROM_STEP=0     # Resume from this step
```

Utility Functions:
- `check_docker_installed()` - Dynamic Docker detection
- `save_progress()` - Save completed step
- `load_progress()` - Load last completed step
- `error_handler()` - Error trap handler
- `validate_config()` - Input validation
- `backup_file()` - Backup existing files

## Adding New Steps

### CRITICAL RULE

File Permissions (Step N-1) and Cleanup (Step N) must ALWAYS be the final two steps.

Insert new steps BEFORE File Permissions, then renumber:
- Current: Steps 1-22, Step 23 (File Permissions), Step 24 (Cleanup)
- New: Steps 1-22, **Step 23 (New Step)**, Step 24 (File Permissions), Step 25 (Cleanup)

### Step-by-Step Guide

#### 1. Update Constants

```bash
# Line 48 - Increment total steps
readonly TOTAL_STEPS=25  # Was 24, now 25

# Lines 62-88 - Add step name to array
declare -a STEP_NAMES=(
    ""
    "System Updates"
    # ... existing steps ...
    "Log Monitoring"
    "Your New Step"          # Add here
    "File Permissions"       # Renumber from 23 to 24
    "Cleanup"                # Renumber from 24 to 25
)
```

#### 2. Add Step Implementation

Insert BEFORE File Permissions step (around line 1975):

```bash
# ============================================================================
# STEP 23: YOUR NEW STEP NAME
# ============================================================================
if [ $START_FROM_STEP -le 23 ]; then
    log_info "Step 23/$TOTAL_STEPS: Your description..."

    # Implementation here

    LAST_STEP=23        # Set BEFORE save_progress
    save_progress 23
fi

# ============================================================================
# STEP 24: FILE PERMISSIONS (renumbered from 23)
# ============================================================================
if [ $START_FROM_STEP -le 24 ]; then
    log_info "Step 24/$TOTAL_STEPS: Setting secure file permissions..."
    # ... existing code ...
    LAST_STEP=24
    save_progress 24
fi

# ============================================================================
# STEP 25: CLEANUP (renumbered from 24)
# ============================================================================
if [ $START_FROM_STEP -le 25 ]; then
    log_info "Step 25/$TOTAL_STEPS: Cleaning up..."
    # ... existing code ...
    LAST_STEP=25
    save_progress 25
fi
```

#### 3. Update Help Text

Lines 235-271 in `show_help()`:

```bash
Steps:
  1  - System updates
  ...
  22 - Log monitoring
  23 - Your new step              # Add here
  24 - File permissions           # Renumbered
  25 - Cleanup                    # Renumbered
```

#### 4. Update Summary

Lines 2162-2230:

```bash
cat << EOF
System updated and automatic security updates enabled
...
Log monitoring configured (daily checks)
Your new feature configured               # Add here
File permissions secured                  # Always second to last
Cleanup completed                         # Always last
EOF
```

## Code Patterns

### Step Structure Template

```bash
# ============================================================================
# STEP N: STEP NAME
# ============================================================================
if [ $START_FROM_STEP -le N ]; then
    log_info "Step N/$TOTAL_STEPS: Description..."

    # Implementation

    LAST_STEP=N          # Set BEFORE save_progress
    save_progress N
fi
```

### Conditional Step (Docker-dependent)

```bash
if [ $START_FROM_STEP -le N ]; then
    if check_docker_installed; then
        log_info "Step N/$TOTAL_STEPS: Docker feature..."

        # Implementation

        LAST_STEP=N
        save_progress N
    else
        log_info "Step N/$TOTAL_STEPS: Skipping (Docker not installed)"
        LAST_STEP=N
        save_progress N
    fi
fi
```

### Logging

```bash
log_info "Normal message"
log_warn "Warning message"
log_error "Critical error"
```

### File Backup

```bash
backup_file /etc/important.conf

cat > /etc/important.conf << 'EOF'
new content
EOF
```

### Service Management

```bash
systemctl restart service-name

if systemctl is-active --quiet service-name; then
    log_info "Service started"
    LAST_STEP=N
    save_progress N
else
    log_error "Service failed. Check: journalctl -u service-name"
    exit 1
fi
```

### Configuration Validation

```bash
TEMP_CONFIG=$(mktemp)
cat > "$TEMP_CONFIG" << 'EOF'
configuration
EOF

if command-name --test "$TEMP_CONFIG"; then
    mv "$TEMP_CONFIG" /etc/final.conf
    log_info "Configuration applied"
else
    rm -f "$TEMP_CONFIG"
    log_error "Validation failed"
    exit 1
fi
```

### Secure Temp Files

```bash
# GOOD
TEMP_FILE=$(mktemp)
echo "data" > "$TEMP_FILE"

# BAD
echo "data" > /tmp/myfile.txt
```

### Downloading Scripts

```bash
# GOOD
INSTALLER=$(mktemp)
if curl -fsSL https://example.com/install.sh -o "$INSTALLER"; then
    bash "$INSTALLER"
    rm -f "$INSTALLER"
else
    log_error "Download failed"
    rm -f "$INSTALLER"
    exit 1
fi

# BAD
curl -fsSL https://example.com/install.sh | bash
```

### Cron Scripts

```bash
cat > /etc/cron.daily/your-script << 'EOF'
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

# Script content
EOF

chmod +x /etc/cron.daily/your-script
```

### Docker Container Iteration

```bash
# GOOD
docker ps --quiet 2>/dev/null | while read -r container; do
    name=$(docker inspect --format '{{ .Name }}' "$container" 2>/dev/null)
    echo "$name"
done

# BAD
for container in $(docker ps --quiet); do
    # Word splitting issues
done
```

### File Permissions

```bash
# GOOD - Selective
for log in auth.log secure syslog; do
    [ -f "/var/log/$log" ] && chmod 640 "/var/log/$log" 2>/dev/null || true
done

# BAD - Too broad
find /var/log -type f -exec chmod o-r {} \;
```

### Error Handling

```bash
# GOOD
if sysctl -p /etc/sysctl.d/99-security.conf; then
    log_info "Applied successfully"
else
    log_warn "Some settings failed. Check: dmesg | tail"
fi

# BAD
sysctl -p /etc/sysctl.d/99-security.conf >/dev/null 2>&1
```

## Error Handling

### Exit Trap

```bash
trap 'error_handler ${LINENO}' ERR
```

Any failing command triggers error handler with resume instructions.

### Expected Failures

```bash
# Allow failure
some-command || true

# Check and handle
if some-command; then
    log_info "Success"
else
    log_warn "Failed but continuing"
fi

# Critical failure
if ! critical-command; then
    log_error "Critical failure"
    exit 1
fi
```

### Lock File Management

```bash
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    log_error "Another instance running"
    exit 1
fi

trap 'flock -u 200 2>/dev/null || true; rm -f "$LOCK_FILE" 2>/dev/null || true' EXIT
```

## Testing

### Syntax Check
```bash
bash -n init.sh
```

### Test Individual Step
```bash
sudo ./init.sh --continue N
```

### Test Resume
```bash
# Simulate failure at step 5 (add 'exit 1')
sudo ./init.sh

# Resume
sudo ./init.sh --continue 6
```

### Verify Logging
```bash
cat /var/tmp/server-init-step
sudo tail -f /var/log/server-init-progress.log
```

### Check Help
```bash
./init.sh --help
```

## Common Pitfalls

### 1. Forgetting to Update TOTAL_STEPS

```bash
# BAD
readonly TOTAL_STEPS=24  # Added step 25 but forgot to update

# GOOD
readonly TOTAL_STEPS=25
```

### 2. Setting LAST_STEP Too Early

```bash
# BAD - If step fails, marked as complete
if [ $START_FROM_STEP -le 25 ]; then
    LAST_STEP=25
    apt install -y package
    save_progress 25
fi

# GOOD
if [ $START_FROM_STEP -le 25 ]; then
    apt install -y package
    LAST_STEP=25        # Set BEFORE save_progress
    save_progress 25
fi
```

### 3. Missing Step Name in Array

```bash
# BAD - Missing step 25
declare -a STEP_NAMES=(
    ""
    "System Updates"
    # ... steps 2-24 ...
    "Cleanup"
)

# GOOD
declare -a STEP_NAMES=(
    ""
    "System Updates"
    # ... steps 2-24 ...
    "Your New Step"     # Step 25
    "Cleanup"           # Step 26
)
```

### 4. Wrong Docker Detection

```bash
# BAD
if [ "$DOCKER_INSTALLED" = true ]; then
    # Breaks in --continue mode
fi

# GOOD
if check_docker_installed; then
    # Works in all modes
fi
```

### 5. Hardcoded Step Numbers

```bash
# BAD
if [ $LAST_STEP -ge 7 ]; then
    # Assume Docker installed
fi

# GOOD
if check_docker_installed; then
    # Direct check
fi
```

### 6. Forgetting chmod on Cron Scripts

```bash
# BAD
cat > /etc/cron.daily/script << 'EOF'
#!/bin/bash
echo "test"
EOF
# Missing chmod

# GOOD
cat > /etc/cron.daily/script << 'EOF'
#!/bin/bash
echo "test"
EOF
chmod +x /etc/cron.daily/script
```

### 7. No Configuration Validation

```bash
# BAD
echo "$INPUT" > /etc/config.conf
systemctl restart service

# GOOD
if [[ ! "$INPUT" =~ ^[a-zA-Z0-9]+$ ]]; then
    log_error "Invalid input"
    exit 1
fi

echo "$INPUT" > /etc/config.conf
if systemctl restart service; then
    log_info "Restarted"
else
    log_error "Failed to start"
    exit 1
fi
```

### 8. Relative Paths

```bash
# BAD
source .env.init
cat config.txt > /etc/myconfig

# GOOD
source "$CONFIG_FILE"
cat /absolute/path/config.txt > /etc/myconfig
```

### 9. Not Handling Existing Configs

```bash
# BAD
cat > /etc/important.conf << 'EOF'
new config
EOF

# GOOD
if [ -f /etc/important.conf ]; then
    backup_file /etc/important.conf
    log_warn "Existing config backed up"
fi

cat > /etc/important.conf << 'EOF'
new config
EOF
```

### 10. Ignoring Non-Interactive Mode

```bash
# BAD
read -p "Install Docker? [y/N] " REPLY

# GOOD
INSTALL_DOCKER=false

if [ -t 0 ]; then
    read -p "Install Docker? [y/N] " -r
    [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_DOCKER=true
else
    log_info "Non-interactive: skipping Docker"
fi
```

## Checklist

When adding new step, verify:

- [ ] CRITICAL: Inserted BEFORE File Permissions (not after Cleanup)
- [ ] CRITICAL: File Permissions and Cleanup renumbered to N-1 and N
- [ ] TOTAL_STEPS incremented
- [ ] Step name added to STEP_NAMES array
- [ ] Help text updated
- [ ] Step follows `if [ $START_FROM_STEP -le N ]` pattern
- [ ] LAST_STEP=N set RIGHT BEFORE save_progress N
- [ ] Used mktemp for temp files
- [ ] Backed up existing files
- [ ] Validated configuration
- [ ] Verified services started
- [ ] Used check_docker_installed() not $DOCKER_INSTALLED
- [ ] Set PATH in cron scripts
- [ ] Made cron scripts executable
- [ ] Used safe iteration
- [ ] Didn't suppress errors
- [ ] Tested syntax: `bash -n init.sh`
- [ ] Tested in VM
- [ ] Updated summary

## Example: Adding Fail2Ban

Adding as Step 23 (pushes File Permissions to 24, Cleanup to 25).

### 1. Update Constants

```bash
# Line 48
readonly TOTAL_STEPS=25  # Was 24

# Lines 62-88
declare -a STEP_NAMES=(
    ""
    "System Updates"
    # ... existing steps ...
    "Log Monitoring"
    "Fail2Ban"              # New step 23
    "File Permissions"      # Was 23, now 24
    "Cleanup"               # Was 24, now 25
)
```

### 2. Add Implementation

Insert BEFORE File Permissions (line ~1975):

```bash
# ============================================================================
# STEP 23: FAIL2BAN
# ============================================================================
if [ $START_FROM_STEP -le 23 ]; then
    log_info "Step 23/$TOTAL_STEPS: Installing Fail2Ban..."

    apt install -y fail2ban

    backup_file /etc/fail2ban/jail.local

    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200
EOF

    systemctl restart fail2ban
    systemctl enable fail2ban

    if systemctl is-active --quiet fail2ban; then
        log_info "Fail2Ban running"
    else
        log_error "Fail2Ban failed. Check: journalctl -u fail2ban"
        exit 1
    fi

    LAST_STEP=23
    save_progress 23
fi

# ============================================================================
# STEP 24: FILE PERMISSIONS (renumbered from 23)
# ============================================================================
if [ $START_FROM_STEP -le 24 ]; then
    log_info "Step 24/$TOTAL_STEPS: Setting file permissions..."
    # ... existing code ...
    LAST_STEP=24
    save_progress 24
fi

# ============================================================================
# STEP 25: CLEANUP (renumbered from 24)
# ============================================================================
if [ $START_FROM_STEP -le 25 ]; then
    log_info "Step 25/$TOTAL_STEPS: Cleaning up..."
    # ... existing code ...
    LAST_STEP=25
    save_progress 25
fi
```

### 3. Update Help

```bash
Steps:
  ...
  22 - Log monitoring
  23 - Fail2Ban
  24 - File permissions
  25 - Cleanup
```

### 4. Update Summary

```bash
Log monitoring configured
Fail2Ban configured
File permissions secured
Cleanup completed
```

### 5. Test

```bash
bash -n init.sh
sudo ./init.sh --continue 23
sudo fail2ban-client status
```

## Best Practices

1. Always backup before modifying
2. Validate before applying
3. Verify services started
4. Log appropriately (info/warn/error)
5. Use mktemp for temp files
6. Set PATH in cron
7. Handle non-interactive mode
8. Don't suppress errors
9. Use absolute paths
10. Test in VM first

Last Updated: 2025-11-22
Script Version: 24 steps (expandable)
Purpose: AI-generated scripts for personal use
