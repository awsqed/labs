# AI Agent Instructions

Personal repository of AI-generated Ubuntu server infrastructure automation scripts.

## Repository Context

This is a personal repository. All files are AI-generated for personal use only.

## AI Workflow Rules

### Core Principles

- Optimize responses for clarity and context efficiency
- Ask follow-up questions when information is missing or ambiguous - never assume
- Present a plan first, execute only after explicit approval
- Perform ONLY requested actions - do not add related/helpful extras

### Clarification Protocol

When request is unclear or incomplete:
- List specific information needed
- Provide 2-3 concrete examples if helpful
- Wait for answers before proceeding

### Workflow

1. Understand request
2. Ask clarifying questions if needed
3. Present plan with clear steps
4. Wait for approval ("yes"/"approved"/"go ahead")
5. Execute approved plan exactly as stated
6. Stop when complete - do not suggest next steps unless asked

### Scope Boundaries

OUT OF SCOPE (requires explicit permission):
- Code refactoring not requested
- Adding features/functions beyond stated requirements
- Creating additional files/components
- Optimizations or improvements not asked for
- Documentation unless specifically requested
- Testing/validation beyond what's stated

When in doubt: ASK before doing.

## Critical Architectural Rules

### Init Script Step Ordering (NON-NEGOTIABLE)

File Permissions and Cleanup MUST be final two steps in `common/ubuntu/server/init/init.sh`:

- Current: Steps 1-22, File Permissions (23), Cleanup (24)
- Adding Step 23: Steps 1-22, **New (23)**, File Permissions (24), Cleanup (25)
- Update: `TOTAL_STEPS`, `STEP_NAMES` array, help text, summary
- See: `common/ubuntu/server/init/NEW-STEP-TEMPLATE.sh`

### Step Implementation Pattern

```bash
if [ $START_FROM_STEP -le N ]; then
    log_info "Step N/$TOTAL_STEPS: Description..."

    # Implementation

    LAST_STEP=N          # Set BEFORE save_progress
    save_progress N
fi
```

**Critical**: Set `LAST_STEP` immediately before `save_progress`. Use `check_docker_installed()` function, not `$DOCKER_INSTALLED` variable.

### Systemd Service Standard

All `.service` files follow `common/SYSTEMD-SERVICE-STANDARD.md`:

- Directive order: [Unit] Description→After/Before→Requires/Wants, [Service] Type→User/Group→ExecStart→Restart→Security, [Install] WantedBy
- `StartLimitBurst`/`StartLimitIntervalSec` in [Unit], NOT [Service]
- Validate: `systemd-analyze verify` before completion
- Security: `PrivateTmp=yes`, `NoNewPrivileges=true`, `ProtectSystem=strict`

## Project Structure

```
common/
├── SYSTEMD-SERVICE-STANDARD.md      # Systemd template
├── ubuntu/server/
│   ├── init/
│   │   ├── init.sh                  # 24-step hardening (2370 lines)
│   │   ├── DEVELOPER-GUIDE.md       # Pattern reference
│   │   ├── README.md                # Deployment guide
│   │   └── NEW-STEP-TEMPLATE.sh     # Feature template
│   ├── docker-compose-auto.sh       # Multi-project orchestration
│   └── tailscale/                   # Container routing
├── CLAUDE.md                         # AI agent guidelines
└── README.md                         # Repository overview
```

## Development Workflows

### Adding Init Script Steps

1. Read `DEVELOPER-GUIDE.md` for patterns
2. Copy `NEW-STEP-TEMPLATE.sh`
3. Update 4 locations in `init.sh`:
   - Line 48: `TOTAL_STEPS` (increment)
   - Lines 62-88: `STEP_NAMES` (insert before "File Permissions")
   - Lines 235-271: Help text
   - Lines 2162-2230: Summary
4. Insert step BEFORE File Permissions (~line 1975)
5. Renumber: File Permissions (23→24), Cleanup (24→25)
6. Test: `bash -n init.sh` then `sudo ./init.sh --continue N`

### Safety Patterns

| Pattern | Implementation |
|---------|----------------|
| **Temp files** | `TMPFILE=$(mktemp); trap 'rm -f "$TMPFILE"' EXIT` |
| **Cron PATH** | `PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin` |
| **Service verify** | `systemctl restart X && systemctl is-active --quiet X` |
| **Backups** | `backup_file /etc/file.conf` before overwrite |

### File Operations

- Always read files before editing
- Use absolute paths
- Test in VM before production deployment
- Validate syntax before completion

### Docker Compose Auto-Start

`docker-compose-auto.sh` discovers projects in `/opt/docker-projects`:
- Scans for `docker-compose.yml`/`compose.yml`
- `.startup-order` for sequential startup
- `.startup-wait` for delays
- `EXCLUDE_DIRS` environment variable
- Reverse order shutdown with `.startup-order`

### Cleanup Script Architecture

`ubuntu-server-cleanup.sh` features:
- `EXCLUDED_PATTERNS` array prevents deletion of critical paths
- `is_safe_path()` blocks system directory operations
- `check_apt_lock()` with timeout (default 300s)
- Script lock: `/var/lock/ubuntu_cleanup_server.lock`
- Kernel retention: N-1 policy
- Config: `/etc/ubuntu_cleanup_server.conf`

## Documentation Standards

- All documentation is optimized for AI consumption
- No emojis unless specifically requested
- Direct, imperative language
- Minimal prose, maximum information density
- No meta-content about "who should read this"

## Code Standards

- Follow language-specific standards in respective documentation files
- For systemd services: See `common/SYSTEMD-SERVICE-STANDARD.md`
- For init scripts: See `common/ubuntu/server/init/DEVELOPER-GUIDE.md`

## Anti-Patterns

| ❌ DON'T | ✅ DO |
|---------|-------|
| Add steps after Cleanup | Insert before File Permissions, renumber |
| Use `$DOCKER_INSTALLED` | Call `check_docker_installed()` |
| Put `StartLimitBurst` in [Service] | Place in [Unit] section |
| Set `LAST_STEP` at step start | Set before `save_progress` |
| Suppress errors: `cmd 2>&1` | Handle: `if cmd; then ... fi` |
| Delete excluded patterns | Check `is_excluded()` first |

## Testing Protocols

| Component | Test Command |
|-----------|--------------|
| Init script | `sudo ./init.sh --continue N` in VM |
| Systemd | `systemd-analyze verify X.service` |
| Cleanup | `sudo ./ubuntu-server-cleanup.sh -d` |

## Reference Files

| Task | Reference |
|------|-----------|
| AI workflow rules | `CLAUDE.md` |
| Init development | `common/ubuntu/server/init/DEVELOPER-GUIDE.md` |
| Init deployment | `common/ubuntu/server/init/README.md` |
| Systemd services | `common/SYSTEMD-SERVICE-STANDARD.md` |

## Validation Checklist

Before completing changes:
- [ ] Read relevant reference docs
- [ ] Init: File Permissions and Cleanup are final two steps
- [ ] Systemd: Directive ordering matches standard
- [ ] Safety: mktemp, PATH, service verify, backups
- [ ] Tested in VM/container (not production)
- [ ] Syntax: `bash -n script.sh` or `systemd-analyze verify`
