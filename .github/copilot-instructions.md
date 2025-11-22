# AI Agent Instructions for Labs Repository

## Repository Overview

Personal collection of AI-generated infrastructure scripts and systemd services for Ubuntu server/desktop management, Docker automation, and Tailscale routing. All code is optimized for AI consumption and automated deployment.

## Critical Architectural Rules

### 1. Init Script Step Ordering (NON-NEGOTIABLE)

**File Permissions and Cleanup MUST ALWAYS be the final two steps** in `common/ubuntu/server/init/init.sh`:
- Current structure: Steps 1-22, File Permissions (23), Cleanup (24)
- When adding Step 23: Insert BEFORE File Permissions, renumber to Steps 1-22, **New Step (23)**, File Permissions (24), Cleanup (25)
- Never insert after Cleanup
- Update `TOTAL_STEPS` constant, `STEP_NAMES` array, help text, and summary

See `common/ubuntu/server/init/NEW-STEP-TEMPLATE.sh` for complete implementation template.

### 2. Step Implementation Pattern

```bash
if [ $START_FROM_STEP -le N ]; then
    log_info "Step N/$TOTAL_STEPS: Description..."

    # Implementation here

    LAST_STEP=N          # Set IMMEDIATELY before save_progress
    save_progress N
fi
```

**Critical**: Set `LAST_STEP` right before `save_progress`, never at step start. Use `check_docker_installed()` function, not `$DOCKER_INSTALLED` variable for conditional Docker features.

### 3. Systemd Service Standard

All `.service` files MUST follow `common/SYSTEMD-SERVICE-STANDARD.md`:
- Directive ordering: [Unit] Description → After/Before → Requires/Wants, [Service] Type → User/Group → ExecStart → Restart → Security, [Install] WantedBy
- `StartLimitBurst` and `StartLimitIntervalSec` belong in `[Unit]`, NOT `[Service]`
- Always validate with `systemd-analyze verify` before completion
- Security hardening: `PrivateTmp=yes`, `NoNewPrivileges=true`, `ProtectSystem=strict`

Example from `docker-compose-auto.service`:
```ini
[Unit]
Description=Docker Compose Auto-Start Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/docker-compose-auto.sh start
```

## Project Structure & Components

```
common/
├── SYSTEMD-SERVICE-STANDARD.md      # Authoritative systemd template
├── ubuntu/
│   ├── server/
│   │   ├── init/                    # 24-step hardening script
│   │   │   ├── init.sh              # Main script (2370 lines)
│   │   │   ├── DEVELOPER-GUIDE.md   # Complete patterns reference
│   │   │   ├── README.md            # Deployment guide
│   │   │   └── NEW-STEP-TEMPLATE.sh # Copy for new features
│   │   ├── docker-compose-auto.sh   # Multi-project orchestration
│   │   ├── docker-compose-auto.service
│   │   └── ubuntu-server-cleanup.sh # Automated maintenance
│   └── desktop/
│       └── ubuntu-desktop-cleanup.sh
└── tailscale/
    ├── tailscale-host-routing.sh    # Docker container routing
    └── tailscale-host-routing.service
```

## Key Development Workflows

### Adding Init Script Steps

1. **Always read** `DEVELOPER-GUIDE.md` first for complete patterns
2. Copy `NEW-STEP-TEMPLATE.sh` as starting point
3. Update 4 locations in `init.sh`:
   - Line 48: `TOTAL_STEPS` constant (increment)
   - Lines 62-88: `STEP_NAMES` array (insert before "File Permissions")
   - Lines 235-271: Help text
   - Lines 2162-2230: Completion summary
4. Insert step BEFORE line ~1975 (File Permissions section)
5. Renumber File Permissions (23→24) and Cleanup (24→25)
6. Test: `bash -n init.sh` then `sudo ./init.sh --continue N` in VM

### Script Safety Patterns

**Temp files**: Always use `mktemp`, never predictable paths:
```bash
TEMP_FILE=$(mktemp)
echo "content" > "$TEMP_FILE"
# Use file...
rm -f "$TEMP_FILE"
```

**Cron scripts**: Set PATH explicitly:
```bash
cat > /etc/cron.daily/script << 'EOF'
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# Script content
EOF
chmod +x /etc/cron.daily/script
```

**Service validation**: Check status after restart:
```bash
systemctl restart service-name
if systemctl is-active --quiet service-name; then
    log_info "Service started"
else
    log_error "Failed. Check: journalctl -u service-name"
    exit 1
fi
```

**File backups**: Use provided function:
```bash
backup_file /etc/important.conf
cat > /etc/important.conf << 'EOF'
new content
EOF
```

### Docker Compose Auto-Start Pattern

`docker-compose-auto.sh` discovers projects in `/opt/docker-projects`:
- Scans for `docker-compose.yml`/`compose.yml`
- Optional `.startup-order` file for sequential startup
- Optional `.startup-wait` file for stabilization delays
- Excludes via `EXCLUDE_DIRS` environment variable
- Reverse order shutdown when using `.startup-order`

Integration with systemd: `Type=oneshot` with `RemainAfterExit=yes` for proper lifecycle management.

### Cleanup Script Architecture

`ubuntu-server-cleanup.sh` features:
- Protected patterns: `EXCLUDED_PATTERNS` array prevents deletion of critical paths (e.g., `hy3dgen`, `Hunyuan3D`, `huggingface`, `.git`, `venv`)
- Safe removal: `is_safe_path()` blocks dangerous operations on system directories
- APT locking: `check_apt_lock()` with configurable timeout (default 300s)
- Script-level locking: `/var/lock/ubuntu_cleanup_server.lock` prevents concurrent runs
- Kernel retention: N-1 policy (current + 1 previous minimum)
- Config file: `/etc/ubuntu_cleanup_server.conf` overrides

When modifying exclusions, add patterns to `EXCLUDED_PATTERNS` array at top of script.

## Documentation Standards

**Version policy**: NEVER increment versions unless explicitly requested. All docs have version headers - leave unchanged when updating content.

**Language style**:
- Direct, imperative language
- No emojis (unless requested)
- Maximum information density
- AI-optimized structure

**File relationships**:
- `README.md` = Deployment/usage guide (for operators)
- `DEVELOPER-GUIDE.md` = Modification patterns (for developers)
- Template files = Starting points for new features

## Common Anti-Patterns to Avoid

❌ **DON'T**: Add steps after Cleanup in init.sh
✅ **DO**: Insert before File Permissions, renumber both final steps

❌ **DON'T**: Use `$DOCKER_INSTALLED` variable check
✅ **DO**: Call `check_docker_installed()` function (works in resume mode)

❌ **DON'T**: Put `StartLimitBurst` in `[Service]` section
✅ **DO**: Place in `[Unit]` section per systemd spec

❌ **DON'T**: Set `LAST_STEP` at beginning of step
✅ **DO**: Set immediately before `save_progress` call

❌ **DON'T**: Suppress errors: `command >/dev/null 2>&1`
✅ **DO**: Handle explicitly: `if command; then ... else log_error ...; fi`

❌ **DON'T**: Delete paths containing exclusion patterns
✅ **DO**: Check `is_excluded()` before removal operations

## Testing Protocols

**Init script**: Test in VM (multipass/local):
```bash
sudo cp .env.init.example .env.init
# Edit config
sudo ./init.sh
# Verify step resume
sudo ./init.sh --continue N
```

**Systemd services**: Validate before deployment:
```bash
systemd-analyze verify myapp.service
sudo systemctl daemon-reload
sudo systemctl start myapp.service
journalctl -u myapp.service -f
```

**Cleanup scripts**: Dry run first:
```bash
sudo ./ubuntu-server-cleanup.sh -d  # Dry run mode
sudo ./ubuntu-server-cleanup.sh     # Actual execution
```

## Critical Reference Files

When modifying specific components:
- Init script development → `common/ubuntu/server/init/DEVELOPER-GUIDE.md` (complete patterns)
- Init script deployment → `common/ubuntu/server/init/README.md` (usage guide)
- Systemd services → `common/SYSTEMD-SERVICE-STANDARD.md` (authoritative template)
- AI conventions → `CLAUDE.md` (repository-wide rules)

## Validation Checklist

Before completing any change:
- [ ] Read relevant reference docs (DEVELOPER-GUIDE.md, SYSTEMD-SERVICE-STANDARD.md)
- [ ] Version numbers unchanged (unless explicitly requested)
- [ ] Init script: File Permissions and Cleanup remain final two steps
- [ ] Systemd: Directive ordering matches standard
- [ ] Safety patterns: mktemp, PATH in cron, service verification, backups
- [ ] Tested in VM/container (not production)
- [ ] Syntax validated: `bash -n script.sh` or `systemd-analyze verify`
