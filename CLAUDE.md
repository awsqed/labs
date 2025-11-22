# Claude AI Agent Guidelines

Instructions for AI agents working on this repository.

## Repository Context

This is a personal repository. All files are AI-generated for personal use only.

## Development Rules

### Versioning Policy

**CRITICAL**: Do NOT increment version numbers in documentation files unless specifically requested by the user.

- Version changes require explicit approval
- Keep version numbers unchanged when updating content
- Apply to all .md files with version headers

### Documentation Standards

- All documentation is optimized for AI consumption
- No emojis unless specifically requested
- Direct, imperative language
- Minimal prose, maximum information density
- No meta-content about "who should read this"

### Code Standards

- Follow language-specific standards in respective documentation files
- For systemd services: See `common/SYSTEMD-SERVICE-STANDARD.md`
- For init scripts: See `common/ubuntu/server/init/DEVELOPER-GUIDE.md`

### File Operations

- Always read files before editing
- Use absolute paths
- Test in VM before production deployment
- Validate syntax before completion

## Project Structure

```
/var/www/html/labs/
   common/
      SYSTEMD-SERVICE-STANDARD.md    # Systemd service file standard
      ubuntu/server/init/             # Ubuntu server init scripts
      tailscale/                      # Tailscale configuration
   CLAUDE.md                           # This file
   README.md                           # Repository overview
```

## Reference Documents

- Systemd standards: `common/SYSTEMD-SERVICE-STANDARD.md`
- Ubuntu init development: `common/ubuntu/server/init/DEVELOPER-GUIDE.md`
- Ubuntu init deployment: `common/ubuntu/server/init/README.md`

Last Updated: 2025-11-22
