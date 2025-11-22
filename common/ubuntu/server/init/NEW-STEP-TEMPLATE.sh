#!/bin/bash
# NEW STEP TEMPLATE
# Copy this template when adding a new step to init.sh

# ==============================================================================
# ⚠️ CRITICAL: File Permissions and Cleanup MUST be the final two steps!
# ==============================================================================
# When adding a new step:
# - Insert it BEFORE Step 23 (File Permissions)
# - Renumber File Permissions from 23 to N-1
# - Renumber Cleanup from 24 to N
# - Your new step becomes Step 23
#
# Example: Adding a new step when current total is 24
# Before: Steps 1-22, File Permissions (23), Cleanup (24)
# After:  Steps 1-22, YOUR STEP (23), File Permissions (24), Cleanup (25)
# ==============================================================================

# ==============================================================================
# INSTRUCTIONS:
# ==============================================================================
# 1. Replace N with 23 (your new step will be step 23)
# 2. Renumber File Permissions to N-1 (24 in this example)
# 3. Renumber Cleanup to N (25 in this example)
# 4. Replace "NEW STEP NAME" with your step name
# 5. Replace "Your description" with what the step does
# 6. Implement your logic in the marked section
# 7. Update these locations in init.sh:
#
#    a) Line 48: readonly TOTAL_STEPS=25 (increment from 24 to 25)
#
#    b) Lines 62-88: Add to STEP_NAMES array BEFORE File Permissions:
#       declare -a STEP_NAMES=(
#           # ... steps 1-22 ...
#           "Log Monitoring"
#           "Your Step Name"        # ← Step 23 (your new step)
#           "File Permissions"      # ← Step 24 (renumbered from 23)
#           "Cleanup"               # ← Step 25 (renumbered from 24)
#       )
#
#    c) Lines 235-271: Add to help text:
#       22 - Log monitoring
#       23 - Your step description
#       24 - File permissions (renumbered)
#       25 - Cleanup (renumbered)
#
#    d) Insert step code BEFORE File Permissions (around line 1975)
#
#    e) Renumber File Permissions step: 23 → 24
#
#    f) Renumber Cleanup step: 24 → 25
#
#    g) Lines 2162-2230: Add to completion summary:
#       ✓ Your feature configured
#       ✓ File permissions secured
#       ✓ Cleanup completed
#
# 8. Run syntax check: bash -n init.sh
# 9. Test in VM: sudo ./init.sh --continue 23
# ==============================================================================

# ============================================================================
# STEP 23: NEW STEP NAME
# ============================================================================
if [ $START_FROM_STEP -le 23 ]; then
    log_info "Step 23/$TOTAL_STEPS: Your description..."

    # ========================================================================
    # IMPLEMENTATION SECTION - Replace with your code
    # ========================================================================

    # Example 1: Install package
    # apt install -y package-name

    # Example 2: Backup existing configuration
    # backup_file /etc/your-config.conf

    # Example 3: Create configuration file
    # cat > /etc/your-config.conf << 'EOF'
    # # Your configuration
    # setting = value
    # EOF

    # Example 4: Enable and start service
    # systemctl enable your-service
    # systemctl restart your-service

    # Example 5: Verify service started
    # if systemctl is-active --quiet your-service; then
    #     log_info "Service started successfully"
    # else
    #     log_error "Service failed to start. Check: journalctl -u your-service"
    #     exit 1
    # fi

    # Example 6: Create a script with proper PATH
    # cat > /usr/local/bin/your-script << 'EOF'
    # #!/bin/bash
    # PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    # export PATH
    #
    # # Your script logic here
    # EOF
    # chmod +x /usr/local/bin/your-script

    # Example 7: Create cron job
    # cat > /etc/cron.daily/your-cron << 'EOF'
    # #!/bin/bash
    # PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    # export PATH
    #
    # /usr/local/bin/your-script
    # EOF
    # chmod +x /etc/cron.daily/your-cron

    # Example 8: Conditional execution (only if Docker is installed)
    # if check_docker_installed; then
    #     log_info "Configuring Docker-specific feature..."
    #     # Docker-specific configuration
    # else
    #     log_info "Skipping Docker-specific configuration (Docker not installed)"
    # fi

    # Example 9: Use secure temp file
    # TEMP_FILE=$(mktemp)
    # echo "content" > "$TEMP_FILE"
    # if validate-command "$TEMP_FILE"; then
    #     mv "$TEMP_FILE" /etc/final.conf
    # else
    #     rm -f "$TEMP_FILE"
    #     log_error "Validation failed"
    #     exit 1
    # fi

    # Example 10: Download and execute script safely
    # INSTALLER=$(mktemp)
    # if curl -fsSL https://example.com/install.sh -o "$INSTALLER"; then
    #     bash "$INSTALLER"
    #     rm -f "$INSTALLER"
    # else
    #     log_error "Download failed"
    #     rm -f "$INSTALLER"
    #     exit 1
    # fi

    # ========================================================================
    # CRITICAL: Always set LAST_STEP and save_progress at the end
    # ========================================================================
    LAST_STEP=23
    save_progress 23
fi

# ============================================================================
# ⚠️ RENUMBER THESE EXISTING STEPS
# ============================================================================
# STEP 24: FILE PERMISSIONS (renumbered from 23)
# - Update: if [ $START_FROM_STEP -le 24 ]
# - Update: log_info "Step 24/$TOTAL_STEPS: ..."
# - Update: LAST_STEP=24
# - Update: save_progress 24

# STEP 25: CLEANUP (renumbered from 24)
# - Update: if [ $START_FROM_STEP -le 25 ]
# - Update: log_info "Step 25/$TOTAL_STEPS: ..."
# - Update: LAST_STEP=25
# - Update: save_progress 25

# ==============================================================================
# CHECKLIST BEFORE COMMITTING:
# ==============================================================================
# [ ] ⚠️ CRITICAL: Inserted step BEFORE File Permissions (not after Cleanup)
# [ ] ⚠️ CRITICAL: Renumbered File Permissions step (23 → 24)
# [ ] ⚠️ CRITICAL: Renumbered Cleanup step (24 → 25)
# [ ] Updated TOTAL_STEPS constant (24 → 25)
# [ ] Added step name to STEP_NAMES array (before File Permissions)
# [ ] Updated help text (show all three: new step, File Permissions, Cleanup)
# [ ] Updated completion summary
# [ ] Used mktemp for temp files (not /tmp/predictable-name)
# [ ] Backed up files before overwriting
# [ ] Validated configuration before applying
# [ ] Verified services started (if applicable)
# [ ] Used check_docker_installed() not $DOCKER_INSTALLED
# [ ] Set PATH in cron scripts
# [ ] Made cron scripts executable (chmod +x)
# [ ] Used safe iteration (while read, not for loop)
# [ ] Didn't suppress errors unnecessarily
# [ ] Tested syntax: bash -n init.sh
# [ ] Tested in VM/container (not production!)
# [ ] LAST_STEP set RIGHT BEFORE save_progress
# ==============================================================================
