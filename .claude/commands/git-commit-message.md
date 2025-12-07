Generate commit message and commit staged changes using git.

## Rules

- NO ads (e.g., "Generated with Claude Code")
- Only commit staged files
- Do NOT use `git add` (user decides what to stage)

## Format

```
<type>(<scope>): <message>

- Bullet point summary of changes
- Additional context if needed
```

## Types

| Type | Use For |
|------|---------|
| feat | New feature |
| fix | Bug fix |
| chore | Maintenance, tooling, deps |
| docs | Documentation |
| refactor | Code restructure (no behavior change) |
| test | Test additions/refactoring |
| style | Formatting (no logic change) |
| perf | Performance improvements |

## Requirements

- Title: lowercase, max 50 chars, no period
- Scope: optional, component/area affected
- Body: explain WHY, not WHAT (optional)
- Bullets: concise, high-level

## Examples

```
feat(auth): add JWT login flow

- Implemented JWT token validation logic
- Added documentation for validation component
```

```
fix(ui): handle null pointer in sidebar
```

```
refactor(api): split user controller logic
```

Avoid: vague titles ("update", "fix stuff"), excessive detail, long titles
