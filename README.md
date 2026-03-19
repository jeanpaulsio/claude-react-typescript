# claude-react-typescript

A Claude Code plugin for React/TypeScript code review and patterns. Provides a dedicated reviewer agent, reference skill, and slash command.

## What's Included

| File | Type | Purpose |
|------|------|---------|
| `agents/react-typescript-reviewer.md` | Agent | Deep code review — React 19, hooks, components, composition, React Router, a11y, types, performance, test quality |
| `skills/react-typescript-patterns/SKILL.md` | Skill | Reference patterns for React 19 hooks, components, composition, React Router, data fetching, forms, testing, error boundaries, accessibility, performance |
| `commands/react-review.md` | Command | `/react-review` slash command to trigger the reviewer |

## Install

```bash
git clone https://github.com/jeanpaulsio/claude-react-typescript.git
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
- **HIGH**: React 19 misuse, stale closures, missing deps, component anti-patterns, `any` types, a11y issues, React Router / Next.js mistakes
- **MEDIUM**: Performance (React Compiler awareness), state management, error handling, test quality
- **LOW**: Code organization, naming, dead code, modernization opportunities

## Coverage

Defaults to **Vite + React Router**. Next.js patterns are in a dedicated section.

- **React 19**: `use()`, `useActionState`, `useFormStatus`, `useOptimistic`, `useId`, `ref` as prop
- **Hooks**: `useReducer` for complex state, `useEffect` cleanup, custom hooks, `useRef` patterns
- **Composition**: Compound components, slots, render props, custom hooks
- **Concurrent**: `useTransition`, `useDeferredValue`
- **React Router**: Lazy routes, loaders, actions, per-route error boundaries
- **Data fetching**: TanStack Query (queries, mutations, pagination), Suspense-based fetching, avoiding waterfalls
- **Forms**: Native forms + `useActionState` + Zod (library-free by default)
- **Error handling**: Error Boundaries, granular boundary placement
- **Testing**: Vitest + RTL philosophy, query priority, integration flows, MSW mocking, what to mock/not mock, a11y testing
- **Performance**: React Compiler as default, manual optimization only when needed
- **TypeScript**: Discriminated unions, generics, `const`/`satisfies`, strict event typing
- **Next.js** (optional): Server/Client Components, Server Actions, App Router patterns

## Updating

```bash
cd claude-react-typescript
git pull
./install.sh
```

## Compatibility

Works alongside [everything-claude-code](https://github.com/anthropics/everything-claude-code). The generic `code-reviewer` handles broad reviews; this plugin goes deep on React/TypeScript specifics.
