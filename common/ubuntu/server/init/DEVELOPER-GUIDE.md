# Ubuntu Server Init Script - Development Guide

Development reference for modifying init.sh.

## Architecture

### File Structure

| Section | Lines | Purpose |
|---------|-------|---------|
| Configuration | 1-40 | Script settings |
| Constants | 42-88 | TOTAL_STEPS, STEP_NAMES |
| Logging | 116-133 | log_info, log_warn, log_error |
| Utilities | 135-267 | Helper functions |
| Arguments | 299-344 | CLI argument parsing |
| Pre-flight | 346-393 | Validation checks |
| Steps 1-24 | 395-2160 | Implementation |
| Summary | 2162-2370 | Completion report |

### Key Components

**Constants:**
```bash
readonly PROGRESS_FILE="/var/log/server-init-progress.log"
readonly STEP_FILE="/var/tmp/server-init-step"
readonly LOCK_FILE="/var/lock/server-init-script.lock"
readonly TOTAL_STEPS=24  # UPDATE when adding steps
```

**Step Names:**
```bash
declare -a STEP_NAMES=(
    ""
    "System Updates"
    "Create New User"
    # Add new step names here
)
```

**Functions:**
- `check_docker_installed()` - Dynamic Docker detection
- `save_progress()` - Save completed step
- `load_progress()` - Load last step
- `error_handler()` - Error trap
- `validate_config()` - Input validation
- `backup_file()` - Backup files

## Adding New Steps

### CRITICAL RULE

File Permissions (N-1) and Cleanup (N) MUST be final two steps.

**Current**: Steps 1-22, File Permissions (23), Cleanup (24)
**Adding Step 23**: Steps 1-22, **New (23)**, File Permissions (24), Cleanup (25)

### Step-by-Step Guide

**1. Update Constants (Line 48):**
```bash
readonly TOTAL_STEPS=25  # Was 24
```

**2. Update STEP_NAMES Array (Lines 62-88):**
```bash
declare -a STEP_NAMES=(
    ""
    "System Updates"
    # ... existing steps ...
    "Log Monitoring"
    "Your New Step"          # Add here
    "File Permissions"       # Renumber 23→24
    "Cleanup"                # Renumber 24→25
)
```

**3. Add Implementation (Before ~line 1975):**
```bash
# ============================================================================
# STEP 23: YOUR NEW STEP NAME
# ============================================================================
if [ $START_FROM_STEP -le 23 ]; then
    log_info "Step 23/$TOTAL_STEPS: Description..."

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

**4. Update Help Text (Lines 235-271):**
```bash
Steps:
  1  - System updates
  ...
  22 - Log monitoring
  23 - Your new step
  24 - File permissions
  25 - Cleanup
```

**5. Update Summary (Lines 2162-2230):**
```bash
cat << EOF
System updated and automatic security updates enabled
...
Log monitoring configured (daily checks)
Your new feature configured
File permissions secured                  # Always second to last
Cleanup completed                         # Always last
EOF
```

## Code Patterns

### Basic Step

```bash
if [ $START_FROM_STEP -le N ]; then
    log_info "Step N/$TOTAL_STEPS: Description..."

    # Implementation

    LAST_STEP=N
    save_progress N
fi
```

### Docker-Dependent Step

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

### Pattern Reference

| Pattern | Implementation |
|---------|----------------|
| **Logging** | `log_info "msg"` / `log_warn "msg"` / `log_error "msg"` |
| **Backup** | `backup_file /etc/file.conf` |
| **Service** | `systemctl restart svc && systemctl is-active --quiet svc` |
| **Temp files** | `TMPFILE=$(mktemp); trap 'rm -f "$TMPFILE"' EXIT` |
| **Validation** | `if cmd --test "$file"; then mv "$file" /etc/; fi` |
| **Cron PATH** | `PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin` |
| **Download** | `curl -fsSL URL -o "$TMPFILE" && bash "$TMPFILE"` |
| **Iteration** | `docker ps -q \| while read -r cid; do ... done` |

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

### Cron Scripts

```bash
cat > /etc/cron.daily/script << 'EOF'
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

# Script content
EOF

chmod +x /etc/cron.daily/script
```

## Error Handling

### Exit Trap

```bash
trap 'error_handler ${LINENO}' ERR
```

Any failing command triggers error handler with resume instructions.

### Handling Expected Failures

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

## Testing

| Test Type | Command |
|-----------|---------|
| Syntax check | `bash -n init.sh` |
| Individual step | `sudo ./init.sh --continue N` |
| Resume capability | Add `exit 1` at step N, run, then `--continue $((N+1))` |
| Logging | `cat /var/tmp/server-init-step`<br>`sudo tail -f /var/log/server-init-progress.log` |

## Common Pitfalls

| ❌ DON'T | ✅ DO |
|---------|-------|
| Forget `TOTAL_STEPS` | Update to 25 when adding step |
| Set `LAST_STEP` early | Set immediately before `save_progress` |
| Miss step in `STEP_NAMES` | Add at correct position |
| Use `$DOCKER_INSTALLED` | Call `check_docker_installed()` |
| Hardcode step numbers | Use `check_docker_installed()` for checks |
| Skip chmod on cron | Always `chmod +x` cron scripts |
| No validation | Validate configs before applying |
| Relative paths | Use absolute paths or `$CONFIG_FILE` |
| Ignore existing configs | Use `backup_file` before overwrite |
| Suppress errors | Handle explicitly with if/else |

## Anti-Patterns

### 1. Wrong LAST_STEP Placement

```bash
# ❌ BAD - If step fails, marked complete
if [ $START_FROM_STEP -le 25 ]; then
    LAST_STEP=25
    apt install -y package
    save_progress 25
fi

# ✅ GOOD
if [ $START_FROM_STEP -le 25 ]; then
    apt install -y package
    LAST_STEP=25
    save_progress 25
fi
```

### 2. Wrong Docker Detection

```bash
# ❌ BAD - Breaks in --continue mode
if [ "$DOCKER_INSTALLED" = true ]; then
    # ...
fi

# ✅ GOOD - Works in all modes
if check_docker_installed; then
    # ...
fi
```

### 3. Unsafe Temp Files

```bash
# ❌ BAD
echo "data" > /tmp/myfile.txt

# ✅ GOOD
TMPFILE=$(mktemp)
echo "data" > "$TMPFILE"
```

### 4. Missing PATH in Cron

```bash
# ❌ BAD
cat > /etc/cron.daily/script << 'EOF'
#!/bin/bash
docker ps
EOF

# ✅ GOOD
cat > /etc/cron.daily/script << 'EOF'
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
docker ps
EOF
```

### 5. No Service Verification

```bash
# ❌ BAD
systemctl restart service

# ✅ GOOD
systemctl restart service
if systemctl is-active --quiet service; then
    log_info "Service started"
else
    log_error "Failed. Check: journalctl -u service"
    exit 1
fi
```

## Validation Checklist

Before completing changes:
- [ ] Inserted BEFORE File Permissions (not after Cleanup)
- [ ] File Permissions and Cleanup renumbered to N-1 and N
- [ ] `TOTAL_STEPS` incremented
- [ ] Step name in `STEP_NAMES` array
- [ ] Help text updated
- [ ] Follows `if [ $START_FROM_STEP -le N ]` pattern
- [ ] `LAST_STEP=N` right before `save_progress N`
- [ ] Used `mktemp` for temp files
- [ ] Backed up existing files
- [ ] Validated configuration
- [ ] Verified services started
- [ ] Used `check_docker_installed()` not `$DOCKER_INSTALLED`
- [ ] Set PATH in cron scripts
- [ ] Made cron scripts executable
- [ ] Didn't suppress errors
- [ ] Tested: `bash -n init.sh`
- [ ] Tested in VM
- [ ] Updated summary
