# claude-react-typescript

A Claude Code plugin for React/TypeScript code review and patterns. Provides a dedicated reviewer agent, reference skill, and slash command.

## What's Included

| File | Type | Purpose |
|------|------|---------|
| `agents/react-typescript-reviewer.md` | Agent | Deep code review for React/TS — hooks, components, Next.js, a11y, types, performance |
| `skills/react-typescript-patterns/SKILL.md` | Skill | Reference patterns for components, hooks, Next.js App Router, testing, accessibility |
| `commands/react-review.md` | Command | `/react-review` slash command to trigger the reviewer |

## Install

```bash
git clone https://github.com/jp/claude-react-typescript.git
cd claude-react-typescript
chmod +x install.sh
./install.sh
```

## Usage

In any Claude Code session inside a React/TypeScript project:

```
/react-review
```

The reviewer runs `tsc --noEmit` and `eslint`, then reviews your changed files for:

- **CRITICAL**: XSS, secrets, hooks rule violations
- **HIGH**: Stale closures, missing deps, component anti-patterns, `any` types, a11y issues, Next.js boundary mistakes
- **MEDIUM**: Performance, state management, error handling
- **LOW**: Code organization, naming, dead code

## Updating

```bash
cd claude-react-typescript
git pull
./install.sh
```

## Compatibility

Works alongside [everything-claude-code](https://github.com/anthropics/everything-claude-code). The generic `code-reviewer` handles broad reviews; this plugin goes deep on React/TypeScript specifics.
