# Claude AI Agent Guidelines

Instructions for AI agents working on this repository.

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

## Development Rules

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
├── CLAUDE.md                         # This file
└── README.md                         # Repository overview
```

## Reference Documents

- Technical implementation details: `.github/copilot-instructions.md`
- Systemd standards: `common/SYSTEMD-SERVICE-STANDARD.md`
- Ubuntu init development: `common/ubuntu/server/init/DEVELOPER-GUIDE.md`
- Ubuntu init deployment: `common/ubuntu/server/init/README.md`
