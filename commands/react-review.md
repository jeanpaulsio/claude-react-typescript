---
description: React/TypeScript code review for hooks, components, Next.js, type safety, a11y, and performance
---

# React/TypeScript Code Review

Comprehensive review of React/TypeScript code changes:

1. Get changed files: `git diff --name-only -- '*.ts' '*.tsx' '*.js' '*.jsx'`

2. Run diagnostics:
   - `npx tsc --noEmit` — type errors
   - `npx eslint` — lint violations
   - `npx next lint` — Next.js specific issues (if applicable)

3. For each changed file, review using the **react-typescript-reviewer** agent

4. Focus areas:
   - **CRITICAL**: XSS, hardcoded secrets, hooks rule violations
   - **HIGH**: Stale closures, missing deps, component anti-patterns, `any` types, a11y
   - **MEDIUM**: Performance, state management, error handling
   - **LOW**: Code organization, naming, dead code

5. Generate severity report with file locations and suggested fixes

6. Block if CRITICAL or HIGH issues found
