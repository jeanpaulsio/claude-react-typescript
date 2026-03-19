---
name: react-typescript-patterns
description: Deep reference for React/TypeScript patterns — React 19 hooks, components, composition, type safety, testing, accessibility, data fetching, performance, and optional Next.js App Router patterns.
origin: claude-react-typescript
---

# React/TypeScript Patterns

Production patterns for React applications with TypeScript. Covers React 19, component design, hooks, composition, type safety, testing, accessibility, data fetching, and performance. Defaults to **Vite + React** (client-side); Next.js patterns are in a [dedicated section](#nextjs-app-router-patterns).

> To run an automated review using these patterns, use the **react-typescript-reviewer** agent or the `/react-review` command.

## When to Activate

- Building or reviewing React components
- Writing custom hooks
- Fixing TypeScript type errors in React code
- Optimizing React performance (re-renders, bundle size, lazy loading)
- Writing tests for React components (React Testing Library, MSW, Vitest)
- Implementing accessible UI patterns
- Managing state (local, global, server)
- Fetching and caching server data (TanStack Query, Suspense)
- Working with React Router (loaders, lazy routes, error boundaries)
- Working with Next.js App Router (Server Components, Server Actions) — [see section](#nextjs-app-router-patterns)

---

## React 19 Hooks

### `use()` — Unwrap Promises and Context

`use()` reads promises and context values during render. Unlike other hooks, it can be called inside conditionals and loops.

```tsx
import { use, Suspense } from 'react'

// Unwrap a promise — must be paired with Suspense
function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise) // Suspends until resolved
  return <h1>{user.name}</h1>
}

// IMPORTANT: Create the promise OUTSIDE the consuming component.
// In client-side React, use a loader, cache, or lift to a parent that doesn't re-render.

// Option 1: React Router loader (recommended for Vite + React Router)
const userRoute = {
  path: '/users/:id',
  loader: ({ params }) => ({ userPromise: fetchUser(params.id!) }),
  element: <UserPage />,
}

function UserPage() {
  const { userPromise } = useLoaderData() as { userPromise: Promise<User> }
  return (
    <Suspense fallback={<Skeleton />}>
      <UserProfile userPromise={userPromise} />
    </Suspense>
  )
}

// Option 2: Stable promise via useRef (when no router loader available)
function UserPage({ userId }: { userId: string }) {
  const promiseRef = useRef<Promise<User> | null>(null)
  if (!promiseRef.current) {
    promiseRef.current = fetchUser(userId)
  }

  return (
    <Suspense fallback={<Skeleton />}>
      <UserProfile userPromise={promiseRef.current} />
    </Suspense>
  )
}

// Conditional context read (impossible with useContext)
function ThemeText({ override }: { override?: boolean }) {
  const theme = override ? 'dark' : use(ThemeContext)
  return <span className={theme}>text</span>
}
```

**Common mistakes:**
- Creating the promise inside the consuming component on every render (causes infinite Suspense loop in client components)
- Creating the promise in a parent that re-renders (same issue — use ref, loader, or cache)
- Forgetting the Suspense boundary (unhandled suspended component)
- Not pairing with an Error Boundary (promise rejections need to be caught)

### `useActionState` — Form Action State

Manages pending, success, and error states for form actions. Replaces the `useState` + `useEffect` + `isLoading` pattern.

```tsx
import { useActionState } from 'react'

async function submitForm(prevState: FormState, formData: FormData): Promise<FormState> {
  const email = formData.get('email') as string
  const result = EmailSchema.safeParse(email)

  if (!result.success) {
    return { error: result.error.flatten().fieldErrors, success: false }
  }

  await api.subscribe(result.data)
  return { error: null, success: true }
}

type FormState = { error: Record<string, string[]> | null; success: boolean }

function SubscribeForm() {
  const [state, action, pending] = useActionState(submitForm, { error: null, success: false })

  return (
    <form action={action}>
      <label htmlFor="email">Email</label>
      <input id="email" name="email" type="email" aria-invalid={!!state.error?.email} />
      {state.error?.email && <span role="alert">{state.error.email[0]}</span>}
      <button type="submit" disabled={pending}>
        {pending ? 'Subscribing...' : 'Subscribe'}
      </button>
      {state.success && <p role="status">Subscribed!</p>}
    </form>
  )
}
```

### `useFormStatus` — Parent Form Status

Reads the submission status of a parent `<form>`. Must be used in a **child** component of the form, not the form itself.

```tsx
import { useFormStatus } from 'react-dom'

// GOOD: Child component reads parent form status
function SubmitButton({ label }: { label: string }) {
  const { pending } = useFormStatus()
  return (
    <button type="submit" disabled={pending}>
      {pending ? 'Saving...' : label}
    </button>
  )
}

// BAD: useFormStatus in the same component as <form> — always returns idle
function BrokenForm() {
  const { pending } = useFormStatus() // Won't work here!
  return <form action={action}><button disabled={pending}>Save</button></form>
}
```

### `useOptimistic` — Instant UI Feedback

Shows an optimistic value while an async action is in progress. Automatically reverts if the action fails.

```tsx
import { useOptimistic } from 'react'

function TodoList({ todos, addTodo }: { todos: Todo[]; addTodo: (text: string) => Promise<void> }) {
  const [optimisticTodos, addOptimistic] = useOptimistic(
    todos,
    (current: Todo[], newText: string) => [
      ...current,
      { id: crypto.randomUUID(), text: newText, pending: true },
    ]
  )

  async function handleAdd(formData: FormData) {
    const text = formData.get('text') as string
    addOptimistic(text) // Show immediately
    await addTodo(text) // Server confirms or reverts
  }

  return (
    <form action={handleAdd}>
      <input name="text" required />
      <button type="submit">Add</button>
      <ul>
        {optimisticTodos.map(todo => (
          <li key={todo.id} style={{ opacity: todo.pending ? 0.5 : 1 }}>{todo.text}</li>
        ))}
      </ul>
    </form>
  )
}
```

### `useId` — Stable IDs for Accessibility

Generates a unique, stable ID that's consistent between server and client rendering. Use for `htmlFor`/`id` pairing, `aria-describedby`, etc.

```tsx
import { useId } from 'react'

function FormField({ label, error }: { label: string; error?: string }) {
  const id = useId()
  const errorId = `${id}-error`

  return (
    <div>
      <label htmlFor={id}>{label}</label>
      <input
        id={id}
        aria-invalid={!!error}
        aria-describedby={error ? errorId : undefined}
      />
      {error && <span id={errorId} role="alert">{error}</span>}
    </div>
  )
}
```

**Don't use `useId` for:** list keys, CSS selectors, or anything passed to external APIs. It generates opaque strings like `:r1:`.

---

## TypeScript Patterns for React

### Discriminated Union Props

Use discriminated unions when a component has mutually exclusive prop sets:

```tsx
// Instead of a bag of optional props that create invalid combinations:
type ButtonProps =
  | { variant: 'link'; href: string; onClick?: never }
  | { variant: 'button'; onClick: () => void; href?: never }
  | { variant: 'submit'; onClick?: never; href?: never }

function Button(props: ButtonProps) {
  switch (props.variant) {
    case 'link':
      return <a href={props.href}>Link</a>
    case 'button':
      return <button onClick={props.onClick}>Click</button>
    case 'submit':
      return <button type="submit">Submit</button>
  }
}
```

### Generic Components

```tsx
interface SelectProps<T> {
  options: T[]
  value: T
  onChange: (value: T) => void
  getLabel: (item: T) => string
  getKey: (item: T) => string
}

function Select<T>({ options, value, onChange, getLabel, getKey }: SelectProps<T>) {
  return (
    <select
      value={getKey(value)}
      onChange={e => {
        const selected = options.find(o => getKey(o) === e.target.value)
        if (selected) onChange(selected)
      }}
    >
      {options.map(option => (
        <option key={getKey(option)} value={getKey(option)}>
          {getLabel(option)}
        </option>
      ))}
    </select>
  )
}

// Usage — T is inferred as User
<Select
  options={users}
  value={selectedUser}
  onChange={setSelectedUser}
  getLabel={u => u.name}
  getKey={u => u.id}
/>
```

### Polymorphic Components with `as` Prop

```tsx
type PolymorphicProps<E extends React.ElementType> = {
  as?: E
  children: React.ReactNode
} & Omit<React.ComponentPropsWithoutRef<E>, 'as' | 'children'>

function Text<E extends React.ElementType = 'span'>({
  as,
  children,
  ...props
}: PolymorphicProps<E>) {
  const Component = as || 'span'
  return <Component {...props}>{children}</Component>
}

// Usage
<Text>Default span</Text>
<Text as="h1" className="title">Heading</Text>
<Text as="a" href="/about">Link text</Text>
```

### `const` Assertions and `satisfies`

```tsx
// as const prevents literal widening
const ROUTES = {
  home: '/',
  dashboard: '/dashboard',
  settings: '/settings',
} as const
// Type: { readonly home: "/"; readonly dashboard: "/dashboard"; readonly settings: "/settings" }

// satisfies validates structure while preserving narrow types
const THEME = {
  colors: { primary: '#0066ff', danger: '#ff3333' },
  spacing: { sm: 4, md: 8, lg: 16 },
} satisfies Record<string, Record<string, string | number>>
// THEME.colors.primary is still '#0066ff', not just string

// Combined: immutable + validated
const STATUS_MAP = {
  active: { label: 'Active', color: 'green' },
  inactive: { label: 'Inactive', color: 'gray' },
} as const satisfies Record<string, { label: string; color: string }>
```

### `ref` as a Regular Prop (React 19)

React 19 removed the need for `forwardRef`. `ref` is now a regular prop:

```tsx
// React 19: ref is just a prop
function Input({ ref, ...props }: React.ComponentProps<'input'>) {
  return <input ref={ref} {...props} />
}

// Old way (pre-React 19) — still works but unnecessary
const Input = forwardRef<HTMLInputElement, InputProps>((props, ref) => {
  return <input ref={ref} {...props} />
})
```

### Strict Event Typing

```tsx
// Form events
function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
  e.preventDefault()
  const formData = new FormData(e.currentTarget)
}

// Input events
function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
  setValue(e.target.value)
}

// Keyboard events
function handleKeyDown(e: React.KeyboardEvent<HTMLDivElement>) {
  if (e.key === 'Escape') close()
}

// Mouse events with currentTarget
function handleClick(e: React.MouseEvent<HTMLButtonElement>) {
  const buttonId = e.currentTarget.dataset.id
}
```

### Typing Children Correctly

```tsx
// Accept any renderable content
interface CardProps {
  children: React.ReactNode
}

// Accept only specific element types
interface TabListProps {
  children: React.ReactElement<TabProps> | React.ReactElement<TabProps>[]
}

// Render prop pattern
interface DataFetcherProps<T> {
  children: (data: T, loading: boolean) => React.ReactNode
}

// No children allowed
interface IconProps {
  name: string
  children?: never
}
```

---

## Component Composition Patterns

### Compound Components

Parent manages state, children render UI. Avoids prop drilling and allows flexible composition:

```tsx
import { createContext, use, useState, useId } from 'react'

// Context for compound component state
type AccordionContextType = {
  openItem: string | null
  toggle: (id: string) => void
}

const AccordionContext = createContext<AccordionContextType | null>(null)

function useAccordion() {
  const ctx = use(AccordionContext)
  if (!ctx) throw new Error('Accordion compound components must be used within <Accordion>')
  return ctx
}

// Parent manages state
function Accordion({ children }: { children: React.ReactNode }) {
  const [openItem, setOpenItem] = useState<string | null>(null)
  const toggle = (id: string) => setOpenItem(prev => (prev === id ? null : id))

  return (
    <AccordionContext value={{ openItem, toggle }}>
      <div role="region">{children}</div>
    </AccordionContext>
  )
}

// Children access shared state through context
function AccordionItem({ id, title, children }: { id: string; title: string; children: React.ReactNode }) {
  const { openItem, toggle } = useAccordion()
  const contentId = useId()
  const isOpen = openItem === id

  return (
    <div>
      <button
        onClick={() => toggle(id)}
        aria-expanded={isOpen}
        aria-controls={contentId}
      >
        {title}
      </button>
      {isOpen && <div id={contentId} role="region">{children}</div>}
    </div>
  )
}

// Usage — flexible composition, no prop drilling
<Accordion>
  <AccordionItem id="faq-1" title="What is React?">
    <p>A JavaScript library for building user interfaces.</p>
  </AccordionItem>
  <AccordionItem id="faq-2" title="What is TypeScript?">
    <p>A typed superset of JavaScript.</p>
  </AccordionItem>
</Accordion>
```

### Slots Pattern

Explicit named areas for content injection:

```tsx
interface CardProps {
  header: React.ReactNode
  children: React.ReactNode
  footer?: React.ReactNode
}

function Card({ header, children, footer }: CardProps) {
  return (
    <div className="card">
      <div className="card-header">{header}</div>
      <div className="card-body">{children}</div>
      {footer && <div className="card-footer">{footer}</div>}
    </div>
  )
}

// Usage — caller controls each slot
<Card
  header={<h2>Settings</h2>}
  footer={<Button onClick={save}>Save changes</Button>}
>
  <SettingsForm />
</Card>
```

### Render Props (When Hooks Aren't Enough)

Use when you need to share behavior that produces JSX, or for headless UI components:

```tsx
interface VirtualListProps<T> {
  items: T[]
  itemHeight: number
  containerHeight: number
  renderItem: (item: T, index: number) => React.ReactNode
}

function VirtualList<T>({ items, itemHeight, containerHeight, renderItem }: VirtualListProps<T>) {
  const [scrollTop, setScrollTop] = useState(0)
  const startIndex = Math.floor(scrollTop / itemHeight)
  const visibleCount = Math.ceil(containerHeight / itemHeight)
  const visibleItems = items.slice(startIndex, startIndex + visibleCount)

  return (
    <div style={{ height: containerHeight, overflow: 'auto' }} onScroll={e => setScrollTop(e.currentTarget.scrollTop)}>
      <div style={{ height: items.length * itemHeight, position: 'relative' }}>
        {visibleItems.map((item, i) => (
          <div key={startIndex + i} style={{ position: 'absolute', top: (startIndex + i) * itemHeight, height: itemHeight }}>
            {renderItem(item, startIndex + i)}
          </div>
        ))}
      </div>
    </div>
  )
}
```

### When to Use Each

| Pattern | Use When | Avoid When |
|---------|----------|------------|
| Plain props | Simple, predictable data flow | Props exceed 3 levels deep |
| Compound components | Flexible, related UI with shared state | One-off components with fixed layout |
| Slots | Fixed layout with customizable areas | Dynamic number of content areas |
| Render props | Shared behavior that produces JSX | A custom hook would suffice |
| Custom hooks | Reusable stateful logic without UI | You need to render specific JSX |

---

## Hooks Deep Dive

### useEffect Cleanup Patterns

```tsx
// Timer cleanup
useEffect(() => {
  const interval = setInterval(tick, 1000)
  return () => clearInterval(interval)
}, [tick])

// Subscription cleanup
useEffect(() => {
  const subscription = eventBus.subscribe('update', handleUpdate)
  return () => subscription.unsubscribe()
}, [handleUpdate])

// AbortController for fetch
useEffect(() => {
  const controller = new AbortController()

  async function fetchData() {
    try {
      const res = await fetch(`/api/users/${id}`, { signal: controller.signal })
      const data = await res.json()
      setUser(data)
    } catch (err) {
      if (err instanceof DOMException && err.name === 'AbortError') return
      setError(err as Error)
    }
  }

  fetchData()
  return () => controller.abort()
}, [id])
```

### Custom Hook Patterns

```tsx
// Return tuple for simple state hooks
function useToggle(initial = false): [boolean, () => void, (v: boolean) => void] {
  const [value, setValue] = useState(initial)
  const toggle = useCallback(() => setValue(v => !v), [])
  return [value, toggle, setValue]
}

// Return object for complex hooks (for simple cases — prefer TanStack Query for production data fetching)
function useAsync<T>(asyncFn: () => Promise<T>, deps: unknown[]) {
  const [state, setState] = useState<{
    data: T | null
    error: Error | null
    loading: boolean
  }>({ data: null, error: null, loading: true })

  useEffect(() => {
    let cancelled = false
    setState(s => ({ ...s, loading: true }))

    asyncFn()
      .then(data => { if (!cancelled) setState({ data, error: null, loading: false }) })
      .catch(error => { if (!cancelled) setState({ data: null, error, loading: false }) })

    return () => { cancelled = true }
  }, deps) // eslint-disable-line react-hooks/exhaustive-deps

  return state
}
```

### useReducer for Complex State

Use `useReducer` when state has multiple related fields or transitions that depend on the current state:

```tsx
type TodoState = {
  todos: Todo[]
  filter: 'all' | 'active' | 'completed'
  editingId: string | null
}

type TodoAction =
  | { type: 'ADD'; text: string }
  | { type: 'TOGGLE'; id: string }
  | { type: 'DELETE'; id: string }
  | { type: 'SET_FILTER'; filter: TodoState['filter'] }
  | { type: 'START_EDIT'; id: string }
  | { type: 'SAVE_EDIT'; id: string; text: string }
  | { type: 'CANCEL_EDIT' }

function todoReducer(state: TodoState, action: TodoAction): TodoState {
  switch (action.type) {
    case 'ADD':
      return {
        ...state,
        todos: [...state.todos, { id: crypto.randomUUID(), text: action.text, completed: false }],
      }
    case 'TOGGLE':
      return {
        ...state,
        todos: state.todos.map(t => t.id === action.id ? { ...t, completed: !t.completed } : t),
      }
    case 'DELETE':
      return {
        ...state,
        todos: state.todos.filter(t => t.id !== action.id),
        editingId: state.editingId === action.id ? null : state.editingId,
      }
    case 'SET_FILTER':
      return { ...state, filter: action.filter }
    case 'START_EDIT':
      return { ...state, editingId: action.id }
    case 'SAVE_EDIT':
      return {
        ...state,
        todos: state.todos.map(t => t.id === action.id ? { ...t, text: action.text } : t),
        editingId: null,
      }
    case 'CANCEL_EDIT':
      return { ...state, editingId: null }
  }
}

function TodoApp() {
  const [state, dispatch] = useReducer(todoReducer, {
    todos: [],
    filter: 'all',
    editingId: null,
  })

  const filtered = useMemo(() => {
    switch (state.filter) {
      case 'active': return state.todos.filter(t => !t.completed)
      case 'completed': return state.todos.filter(t => t.completed)
      default: return state.todos
    }
  }, [state.todos, state.filter])

  // dispatch({ type: 'ADD', text: 'New todo' })
  // dispatch({ type: 'TOGGLE', id: '123' })
}
```

**When to use `useReducer` over `useState`:**
- State has 3+ related fields that change together
- Next state depends on previous state (toggle, increment, append)
- Multiple actions modify the same state (add/edit/delete/filter)
- You want testable state logic (reducer is a pure function)

### useRef Patterns

```tsx
// Previous value ref
function usePrevious<T>(value: T): T | undefined {
  const ref = useRef<T | undefined>(undefined)
  useEffect(() => {
    ref.current = value
  })
  return ref.current
}

// Measuring DOM elements
function useMeasure<T extends HTMLElement>() {
  const ref = useRef<T>(null)
  const [bounds, setBounds] = useState({ width: 0, height: 0 })

  useEffect(() => {
    if (!ref.current) return
    const observer = new ResizeObserver(([entry]) => {
      setBounds({
        width: entry.contentRect.width,
        height: entry.contentRect.height,
      })
    })
    observer.observe(ref.current)
    return () => observer.disconnect()
  }, [])

  return [ref, bounds] as const
}
```

---

## Concurrent Features

### `useTransition` — Non-Urgent Updates

Marks state updates as non-urgent so urgent updates (typing, clicking) aren't blocked:

```tsx
import { useState, useTransition } from 'react'

function SearchPage() {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<Item[]>([])
  const [isPending, startTransition] = useTransition()

  function handleSearch(e: React.ChangeEvent<HTMLInputElement>) {
    const value = e.target.value
    setQuery(value) // Urgent: update input immediately

    startTransition(() => {
      // Non-urgent: can be interrupted by more typing
      setResults(filterItems(value))
    })
  }

  return (
    <div>
      <input value={query} onChange={handleSearch} />
      {isPending && <span>Filtering...</span>}
      <ResultsList results={results} />
    </div>
  )
}
```

**When transitions help:** Filtering large lists, navigating between tabs, updating expensive visualizations.

**When they don't:** Simple state updates, anything already fast (<16ms).

### `useDeferredValue` — Debounce Expensive Renders

Defers re-rendering a value until urgent updates finish. Useful when you can't wrap the update in `startTransition` (e.g., the value comes from props):

```tsx
import { useDeferredValue, useMemo } from 'react'

function SearchResults({ query }: { query: string }) {
  const deferredQuery = useDeferredValue(query)
  const isStale = query !== deferredQuery

  const results = useMemo(() => filterLargeDataset(deferredQuery), [deferredQuery])

  return (
    <div style={{ opacity: isStale ? 0.7 : 1 }}>
      {results.map(item => <ResultItem key={item.id} item={item} />)}
    </div>
  )
}
```

---

## React Router Patterns

### Route Configuration with Lazy Loading

```tsx
import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import { lazy, Suspense } from 'react'

const Dashboard = lazy(() => import('./features/dashboard/DashboardPage'))
const UserProfile = lazy(() => import('./features/users/UserProfilePage'))
const Settings = lazy(() => import('./features/settings/SettingsPage'))

const router = createBrowserRouter([
  {
    path: '/',
    element: <RootLayout />,
    errorElement: <RootError />,
    children: [
      {
        path: 'dashboard',
        element: (
          <Suspense fallback={<PageSkeleton />}>
            <Dashboard />
          </Suspense>
        ),
        loader: dashboardLoader,
      },
      {
        path: 'users/:id',
        element: (
          <Suspense fallback={<PageSkeleton />}>
            <UserProfile />
          </Suspense>
        ),
        loader: userLoader,
        errorElement: <UserError />,
      },
      {
        path: 'settings',
        element: (
          <Suspense fallback={<PageSkeleton />}>
            <Settings />
          </Suspense>
        ),
      },
    ],
  },
])

function App() {
  return <RouterProvider router={router} />
}
```

### Loaders for Data Fetching

Loaders run before the route renders — no loading spinners needed for initial data:

```tsx
import { useLoaderData, type LoaderFunctionArgs } from 'react-router-dom'

// Loader runs before component renders
export async function userLoader({ params }: LoaderFunctionArgs) {
  const user = await api.getUser(params.id!)
  if (!user) throw new Response('Not Found', { status: 404 })
  return { user }
}

function UserProfilePage() {
  const { user } = useLoaderData() as Awaited<ReturnType<typeof userLoader>>

  return (
    <div>
      <h1>{user.name}</h1>
      <p>{user.email}</p>
    </div>
  )
}
```

### Error Boundaries per Route

```tsx
import { useRouteError, isRouteErrorResponse } from 'react-router-dom'

function UserError() {
  const error = useRouteError()

  if (isRouteErrorResponse(error)) {
    return (
      <div role="alert">
        <h2>{error.status === 404 ? 'User not found' : 'Something went wrong'}</h2>
        <p>{error.statusText}</p>
      </div>
    )
  }

  return (
    <div role="alert">
      <h2>Unexpected error</h2>
      <p>{error instanceof Error ? error.message : 'Unknown error'}</p>
    </div>
  )
}
```

### Actions for Mutations

```tsx
import { Form, useActionData, useNavigation, type ActionFunctionArgs } from 'react-router-dom'

export async function updateProfileAction({ request, params }: ActionFunctionArgs) {
  const formData = await request.formData()
  const result = ProfileSchema.safeParse(Object.fromEntries(formData))

  if (!result.success) {
    return { errors: result.error.flatten().fieldErrors }
  }

  await api.updateUser(params.id!, result.data)
  return { success: true }
}

function EditProfileForm() {
  const actionData = useActionData() as { errors?: Record<string, string[]>; success?: boolean }
  const navigation = useNavigation()
  const isSubmitting = navigation.state === 'submitting'

  return (
    <Form method="post">
      <label htmlFor="name">Name</label>
      <input id="name" name="name" />
      {actionData?.errors?.name && <span role="alert">{actionData.errors.name[0]}</span>}

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Saving...' : 'Save'}
      </button>
    </Form>
  )
}
```

---

## Next.js App Router Patterns

> **Skip this section** if you're using Vite + React Router. These patterns are specific to Next.js App Router.

### Server Components (Default)

```tsx
// app/dashboard/page.tsx — Server Component (no 'use client' directive)
import { db } from '@/lib/db'

export default async function DashboardPage() {
  // Direct database access — runs on server only
  const stats = await db.query('SELECT count(*) FROM orders')

  return (
    <div>
      <h1>Dashboard</h1>
      <StatsDisplay stats={stats} />
      {/* Interactive parts are separate client components */}
      <DashboardFilters />
    </div>
  )
}
```

### Client Components (Interactive Leaves)

```tsx
// components/DashboardFilters.tsx
'use client'

import { useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'

export function DashboardFilters() {
  const [dateRange, setDateRange] = useState('7d')
  const [isPending, startTransition] = useTransition()
  const router = useRouter()

  function handleFilterChange(range: string) {
    setDateRange(range)
    startTransition(() => {
      router.push(`/dashboard?range=${range}`)
    })
  }

  return (
    <div>
      <select value={dateRange} onChange={e => handleFilterChange(e.target.value)}>
        <option value="7d">Last 7 days</option>
        <option value="30d">Last 30 days</option>
        <option value="90d">Last 90 days</option>
      </select>
      {isPending && <span>Loading...</span>}
    </div>
  )
}
```

### Server Actions with Zod Validation

```tsx
// app/actions.ts
'use server'

import { revalidatePath } from 'next/cache'
import { z } from 'zod'

const CreatePostSchema = z.object({
  title: z.string().min(1).max(200),
  content: z.string().min(1),
})

export async function createPost(formData: FormData) {
  const parsed = CreatePostSchema.safeParse({
    title: formData.get('title'),
    content: formData.get('content'),
  })

  if (!parsed.success) {
    return { error: parsed.error.flatten().fieldErrors }
  }

  await db.insert('posts', parsed.data)
  revalidatePath('/posts')
  return { success: true }
}
```

### Route Handlers with Validation

```tsx
// app/api/posts/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { z } from 'zod'

const QuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  sort: z.enum(['newest', 'popular']).default('newest'),
})

export async function GET(request: NextRequest) {
  const searchParams = Object.fromEntries(request.nextUrl.searchParams)
  const parsed = QuerySchema.safeParse(searchParams)

  if (!parsed.success) {
    return NextResponse.json(
      { error: 'Invalid parameters', details: parsed.error.flatten() },
      { status: 400 }
    )
  }

  const { page, limit, sort } = parsed.data
  const offset = (page - 1) * limit
  // Safe: sort is validated by Zod enum — only 'newest' or 'popular' reach here
  const orderBy = sort === 'newest' ? 'created_at DESC' : 'likes DESC'
  const posts = await db.query(
    `SELECT * FROM posts ORDER BY ${orderBy} LIMIT $1 OFFSET $2`,
    [limit, offset]
  )

  return NextResponse.json({ data: posts, meta: { page, limit } })
}
```

### Loading and Error UI

```tsx
// app/dashboard/loading.tsx
export default function DashboardLoading() {
  return (
    <div className="animate-pulse">
      <div className="h-8 bg-gray-200 rounded w-1/4 mb-4" />
      <div className="grid grid-cols-3 gap-4">
        {[1, 2, 3].map(i => (
          <div key={i} className="h-32 bg-gray-200 rounded" />
        ))}
      </div>
    </div>
  )
}

// app/dashboard/error.tsx
'use client'

export default function DashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div role="alert">
      <h2>Something went wrong loading the dashboard</h2>
      <p>{error.message}</p>
      <button onClick={reset}>Try again</button>
    </div>
  )
}
```

---

## Error Boundaries

### Class-Based Error Boundary

```tsx
import { Component, type ErrorInfo, type ReactNode } from 'react'

interface ErrorBoundaryProps {
  children: ReactNode
  fallback: ReactNode | ((error: Error, reset: () => void) => ReactNode)
}

interface ErrorBoundaryState {
  error: Error | null
}

class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { error: null }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { error }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('ErrorBoundary caught:', error, info.componentStack)
    // Send to error reporting service
  }

  reset = () => this.setState({ error: null })

  render() {
    if (this.state.error) {
      const { fallback } = this.props
      return typeof fallback === 'function'
        ? fallback(this.state.error, this.reset)
        : fallback
    }
    return this.props.children
  }
}
```

### Using `react-error-boundary` (Recommended)

```tsx
import { ErrorBoundary } from 'react-error-boundary'

function ErrorFallback({ error, resetErrorBoundary }: { error: Error; resetErrorBoundary: () => void }) {
  return (
    <div role="alert">
      <p>Something went wrong:</p>
      <pre>{error.message}</pre>
      <button onClick={resetErrorBoundary}>Try again</button>
    </div>
  )
}

// Wrap feature boundaries, not the entire app
<ErrorBoundary FallbackComponent={ErrorFallback} onError={logToService}>
  <Dashboard />
</ErrorBoundary>
```

### Boundary Placement Strategy

```tsx
// Per-route: catches page-level crashes (Next.js does this with error.tsx)
// Per-feature: isolates failures so one broken widget doesn't kill the page
// Per-data-source: pairs with Suspense for async error handling

function DashboardPage() {
  return (
    <div>
      {/* Each widget fails independently */}
      <ErrorBoundary FallbackComponent={WidgetError}>
        <Suspense fallback={<Skeleton />}>
          <RevenueChart />
        </Suspense>
      </ErrorBoundary>

      <ErrorBoundary FallbackComponent={WidgetError}>
        <Suspense fallback={<Skeleton />}>
          <UserActivity />
        </Suspense>
      </ErrorBoundary>
    </div>
  )
}
```

**What Error Boundaries don't catch:** Event handlers (use try-catch), async code outside render (use try-catch), server-side errors (use error.tsx in Next.js).

---

## Form Patterns

### Native Forms + `useActionState` + Zod (Default)

For most forms, native HTML + React 19 is all you need:

```tsx
import { useActionState } from 'react'
import { z } from 'zod'

const ContactSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  email: z.string().email('Invalid email'),
  message: z.string().min(10, 'Message must be at least 10 characters'),
})

type FormState = {
  errors: Record<string, string[]> | null
  success: boolean
}

async function submitContact(prev: FormState, formData: FormData): Promise<FormState> {
  const raw = Object.fromEntries(formData)
  const result = ContactSchema.safeParse(raw)

  if (!result.success) {
    return { errors: result.error.flatten().fieldErrors, success: false }
  }

  await api.sendContact(result.data)
  return { errors: null, success: true }
}

function ContactForm() {
  const [state, action, pending] = useActionState(submitContact, { errors: null, success: false })

  return (
    <form action={action}>
      <FormField name="name" label="Name" error={state.errors?.name?.[0]} />
      <FormField name="email" label="Email" type="email" error={state.errors?.email?.[0]} />
      <FormField name="message" label="Message" error={state.errors?.message?.[0]} as="textarea" />
      <SubmitButton label="Send" />
      {state.success && <p role="status">Message sent!</p>}
    </form>
  )
}
```

### Controlled Inputs (When You Need Real-Time Validation)

```tsx
function InlineValidationForm() {
  const [email, setEmail] = useState('')
  const [touched, setTouched] = useState(false)

  const result = touched ? EmailSchema.safeParse(email) : null
  const error = result && !result.success ? result.error.issues[0]?.message : null

  return (
    <div>
      <label htmlFor="email">Email</label>
      <input
        id="email"
        value={email}
        onChange={e => setEmail(e.target.value)}
        onBlur={() => setTouched(true)}
        aria-invalid={!!error}
      />
      {error && <span role="alert">{error}</span>}
    </div>
  )
}
```

### When to Reach for a Form Library

Use React Hook Form or Formik **only** for genuinely complex scenarios:
- Multi-step wizards with branching logic and step-level validation
- Forms with 20+ fields and complex cross-field dependencies
- Dynamic field arrays (add/remove rows) with per-row validation

For everything else — login, signup, contact, settings, CRUD forms — native forms + Zod are simpler and have zero runtime cost.

---

## Data Fetching Patterns

### TanStack Query Basics

```tsx
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'

// Query key factory — consistent, type-safe keys
const userKeys = {
  all: ['users'] as const,
  lists: () => [...userKeys.all, 'list'] as const,
  list: (filters: UserFilters) => [...userKeys.lists(), filters] as const,
  details: () => [...userKeys.all, 'detail'] as const,
  detail: (id: string) => [...userKeys.details(), id] as const,
}

// Fetch with useQuery
function UserList({ filters }: { filters: UserFilters }) {
  const { data, isLoading, error } = useQuery({
    queryKey: userKeys.list(filters),
    queryFn: () => api.getUsers(filters),
    staleTime: 5 * 60 * 1000, // Consider fresh for 5 minutes
  })

  if (isLoading) return <Skeleton />
  if (error) return <ErrorMessage error={error} />
  return <ul>{data.map(user => <UserRow key={user.id} user={user} />)}</ul>
}

// Mutate + invalidate
function useDeleteUser() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (userId: string) => api.deleteUser(userId),
    onSuccess: () => {
      // Invalidate all user lists — they're now stale
      queryClient.invalidateQueries({ queryKey: userKeys.lists() })
    },
  })
}
```

### Optimistic Updates with TanStack Query

```tsx
function useUpdateTodo() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (updated: Todo) => api.updateTodo(updated),

    onMutate: async (updated) => {
      await queryClient.cancelQueries({ queryKey: ['todos'] })
      const previous = queryClient.getQueryData<Todo[]>(['todos'])

      queryClient.setQueryData<Todo[]>(['todos'], old =>
        old?.map(t => t.id === updated.id ? updated : t) ?? []
      )

      return { previous }
    },

    onError: (_err, _updated, context) => {
      queryClient.setQueryData(['todos'], context?.previous)
    },

    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['todos'] })
    },
  })
}
```

### Pagination with `useInfiniteQuery`

```tsx
import { useInfiniteQuery } from '@tanstack/react-query'

interface PageResponse<T> {
  data: T[]
  nextCursor: string | null
}

function useUserList(filters: UserFilters) {
  return useInfiniteQuery({
    queryKey: userKeys.list(filters),
    queryFn: ({ pageParam }) => api.getUsers({ ...filters, cursor: pageParam }),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage: PageResponse<User>) => lastPage.nextCursor ?? undefined,
  })
}

function UserList({ filters }: { filters: UserFilters }) {
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage, isLoading, error } = useUserList(filters)

  if (isLoading) return <Skeleton />
  if (error) return <ErrorMessage error={error} />

  const users = data.pages.flatMap(page => page.data)

  return (
    <div>
      <ul>
        {users.map(user => <UserRow key={user.id} user={user} />)}
      </ul>
      {hasNextPage && (
        <button onClick={() => fetchNextPage()} disabled={isFetchingNextPage}>
          {isFetchingNextPage ? 'Loading more...' : 'Load more'}
        </button>
      )}
    </div>
  )
}
```

### Suspense-Based Data Fetching with `use()`

```tsx
import { use, Suspense } from 'react'
import { ErrorBoundary } from 'react-error-boundary'
import { useLoaderData, type LoaderFunctionArgs } from 'react-router-dom'

// Start fetches in a loader — promises are stable across renders
export function dashboardLoader() {
  return {
    revenuePromise: fetchRevenue(),
    usersPromise: fetchActiveUsers(),
  }
}

function DashboardPage() {
  const { revenuePromise, usersPromise } = useLoaderData() as ReturnType<typeof dashboardLoader>

  return (
    <div>
      {/* Parallel Suspense boundaries — both fetch simultaneously */}
      <ErrorBoundary FallbackComponent={WidgetError}>
        <Suspense fallback={<Skeleton />}>
          <RevenueChart dataPromise={revenuePromise} />
        </Suspense>
      </ErrorBoundary>

      <ErrorBoundary FallbackComponent={WidgetError}>
        <Suspense fallback={<Skeleton />}>
          <UserCount dataPromise={usersPromise} />
        </Suspense>
      </ErrorBoundary>
    </div>
  )
}

function RevenueChart({ dataPromise }: { dataPromise: Promise<Revenue[]> }) {
  const data = use(dataPromise)
  return <Chart data={data} />
}
```

### Avoiding Waterfalls

```tsx
// BAD: Sequential fetches — each waits for the previous
function Profile({ userId }: { userId: string }) {
  const user = use(fetchUser(userId))           // Fetch 1
  const posts = use(fetchPosts(userId))          // Waits for Fetch 1
  const followers = use(fetchFollowers(userId))  // Waits for Fetch 2
  // ...
}

// GOOD: Parallel fetches via React Router loader
export function profileLoader({ params }: LoaderFunctionArgs) {
  // All three start simultaneously — no waterfall
  return {
    userPromise: fetchUser(params.id!),
    postsPromise: fetchPosts(params.id!),
    followersPromise: fetchFollowers(params.id!),
  }
}

function ProfilePage() {
  const { userPromise, postsPromise, followersPromise } = useLoaderData() as Awaited<ReturnType<typeof profileLoader>>

  return (
    <>
      <Suspense fallback={<Skeleton />}>
        <ProfileHeader userPromise={userPromise} />
      </Suspense>
      <Suspense fallback={<PostsSkeleton />}>
        <PostsList postsPromise={postsPromise} />
      </Suspense>
      <Suspense fallback={<FollowersSkeleton />}>
        <FollowersList followersPromise={followersPromise} />
      </Suspense>
    </>
  )
}
```

---

## Testing Patterns

### Testing Philosophy

**Test behavior, not implementation.** A test should break when the user-facing behavior changes, not when you refactor internals.

```tsx
// BAD: Tests implementation (component state, internal methods)
expect(component.state.isOpen).toBe(true)
expect(wrapper.instance().handleClick).toHaveBeenCalled()

// GOOD: Tests what the user sees and does
expect(screen.getByRole('dialog')).toBeInTheDocument()
await user.click(screen.getByRole('button', { name: /close/i }))
expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
```

### Query Priority

Use the most accessible query first. This doubles as an accessibility audit — if you can't query by role, your component may have a11y issues:

```tsx
// 1. getByRole — best; tests accessibility tree
screen.getByRole('button', { name: /submit/i })
screen.getByRole('heading', { level: 2 })
screen.getByRole('textbox', { name: /email/i })

// 2. getByLabelText — forms
screen.getByLabelText(/password/i)

// 3. getByPlaceholderText — when no label exists
screen.getByPlaceholderText(/search/i)

// 4. getByText — non-interactive content
screen.getByText(/no results found/i)

// 5. getByTestId — last resort only
screen.getByTestId('complex-canvas-widget')
```

If you reach for `getByTestId` on a button or link, reconsider whether the element has proper a11y attributes.

### `userEvent` vs `fireEvent`

Always prefer `userEvent` — it simulates real browser behavior (focus, blur, keyboard events, pointer events). `fireEvent` dispatches a single synthetic event.

```tsx
import userEvent from '@testing-library/user-event'

// GOOD: userEvent simulates full interaction chain
const user = userEvent.setup()
await user.click(button)      // fires pointerdown, pointerup, mousedown, mouseup, click, focus
await user.type(input, 'hello') // fires focus, keydown, keypress, input, keyup per character
await user.tab()                // moves focus like a real Tab press

// AVOID: fireEvent dispatches only the named event
fireEvent.click(button)  // Only fires click — no focus, no pointer events
fireEvent.change(input, { target: { value: 'hello' } }) // Skips keyboard events
```

### Component Tests with Vitest + RTL

```tsx
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, vi } from 'vitest'
import { SearchForm } from './SearchForm'

describe('SearchForm', () => {
  it('calls onSearch with debounced input value', async () => {
    const user = userEvent.setup()
    const onSearch = vi.fn()

    render(<SearchForm onSearch={onSearch} />)

    await user.type(screen.getByRole('searchbox'), 'react patterns')

    await waitFor(() => {
      expect(onSearch).toHaveBeenCalledWith('react patterns')
    })
  })

  it('shows validation error for empty submission', async () => {
    const user = userEvent.setup()
    render(<SearchForm onSearch={vi.fn()} />)

    await user.click(screen.getByRole('button', { name: /search/i }))

    expect(screen.getByRole('alert')).toHaveTextContent('Search query is required')
  })

  it('disables submit button while loading', () => {
    render(<SearchForm onSearch={vi.fn()} loading />)
    expect(screen.getByRole('button', { name: /search/i })).toBeDisabled()
  })
})
```

### Integration Tests (Multi-Step User Flows)

Test complete workflows that cross component boundaries:

```tsx
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'
import { App } from './App'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const server = setupServer(
  http.get('/api/todos', () => {
    return HttpResponse.json([
      { id: '1', text: 'Buy milk', completed: false },
      { id: '2', text: 'Walk dog', completed: true },
    ])
  }),
  http.post('/api/todos', async ({ request }) => {
    const body = await request.json() as { text: string }
    return HttpResponse.json({ id: '3', text: body.text, completed: false }, { status: 201 })
  }),
  http.patch('/api/todos/:id', async ({ params }) => {
    return HttpResponse.json({ id: params.id, completed: true })
  })
)

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

function renderApp() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return render(
    <QueryClientProvider client={queryClient}>
      <App />
    </QueryClientProvider>
  )
}

describe('Todo workflow', () => {
  it('loads todos, adds a new one, and marks it complete', async () => {
    const user = userEvent.setup()
    renderApp()

    // Wait for initial load
    await waitFor(() => {
      expect(screen.getByText('Buy milk')).toBeInTheDocument()
    })

    // Add a new todo
    await user.type(screen.getByRole('textbox', { name: /new todo/i }), 'Read book')
    await user.click(screen.getByRole('button', { name: /add/i }))

    await waitFor(() => {
      expect(screen.getByText('Read book')).toBeInTheDocument()
    })

    // Mark it complete
    const newTodo = screen.getByText('Read book').closest('li')!
    await user.click(within(newTodo).getByRole('checkbox'))

    await waitFor(() => {
      expect(within(newTodo).getByRole('checkbox')).toBeChecked()
    })
  })
})
```

### Testing with Providers (Wrapper Setup)

Most components need providers (router, query client, theme). Create a reusable wrapper:

```tsx
// test/utils.tsx
import { render, type RenderOptions } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { ThemeProvider } from '@/components/ThemeProvider'

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
      mutations: { retry: false },
    },
  })
}

function AllProviders({ children }: { children: React.ReactNode }) {
  const queryClient = createTestQueryClient()
  return (
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <ThemeProvider>
          {children}
        </ThemeProvider>
      </MemoryRouter>
    </QueryClientProvider>
  )
}

function renderWithProviders(ui: React.ReactElement, options?: Omit<RenderOptions, 'wrapper'>) {
  return render(ui, { wrapper: AllProviders, ...options })
}

export { renderWithProviders as render }
export { screen, waitFor } from '@testing-library/react'
```

### Mocking API Calls with MSW

```tsx
import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'

const server = setupServer(
  http.get('/api/users/:id', ({ params }) => {
    return HttpResponse.json({
      id: params.id,
      name: 'Jane Doe',
      email: 'jane@example.com',
    })
  })
)

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

// Override for specific test
it('shows error state on API failure', async () => {
  server.use(
    http.get('/api/users/:id', () => {
      return new HttpResponse(null, { status: 500 })
    })
  )

  render(<UserProfile userId="123" />)

  await waitFor(() => {
    expect(screen.getByRole('alert')).toBeInTheDocument()
  })
})
```

### What to Mock and What NOT to Mock

| Mock | Don't Mock |
|------|-----------|
| Network requests (use MSW) | Component internals (state, refs) |
| Timers (`vi.useFakeTimers()`) | User interactions (use userEvent) |
| Browser APIs not in jsdom (`IntersectionObserver`, `matchMedia`) | React itself (render, hooks) |
| Third-party services (payment, email) | Your own components (render them for real) |
| `Date.now()` for time-dependent logic | DOM queries (use RTL queries) |

**Rule of thumb:** Mock at the network boundary (MSW), not inside your code. If you're mocking 3+ things in a test, you're probably testing implementation details.

### Snapshot Testing Guidance

**Don't snapshot JSX.** Snapshots of rendered HTML are fragile, unreadable, and get rubber-stamped in reviews.

```tsx
// BAD: JSX snapshot — breaks on any class name, text, or structure change
expect(container).toMatchSnapshot()

// ACCEPTABLE: Snapshot of serialized data (API responses, config objects)
expect(normalizeUserData(rawApiResponse)).toMatchInlineSnapshot(`
  {
    "email": "jane@example.com",
    "name": "Jane Doe",
  }
`)
```

### Accessibility Testing in Unit Tests

```tsx
import { axe, toHaveNoViolations } from 'jest-axe' // or vitest-axe

expect.extend(toHaveNoViolations)

it('has no accessibility violations', async () => {
  const { container } = render(<LoginForm />)
  const results = await axe(container)
  expect(results).toHaveNoViolations()
})
```

Automated a11y tools catch ~57% of issues. Use them as a baseline, not a replacement for manual testing with screen readers.

### Testing Custom Hooks

```tsx
import { renderHook, act } from '@testing-library/react'
import { useToggle } from './useToggle'

describe('useToggle', () => {
  it('starts with initial value', () => {
    const { result } = renderHook(() => useToggle(true))
    expect(result.current[0]).toBe(true)
  })

  it('toggles value', () => {
    const { result } = renderHook(() => useToggle(false))

    act(() => { result.current[1]() })
    expect(result.current[0]).toBe(true)

    act(() => { result.current[1]() })
    expect(result.current[0]).toBe(false)
  })
})
```

---

## Accessibility Patterns

### Focus Trap for Modals

```tsx
function useFocusTrap(isActive: boolean) {
  const containerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!isActive || !containerRef.current) return

    const focusableSelector = 'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    const focusableElements = containerRef.current.querySelectorAll<HTMLElement>(focusableSelector)
    const firstElement = focusableElements[0]
    const lastElement = focusableElements[focusableElements.length - 1]

    function handleTab(e: KeyboardEvent) {
      if (e.key !== 'Tab') return

      if (e.shiftKey) {
        if (document.activeElement === firstElement) {
          e.preventDefault()
          lastElement?.focus()
        }
      } else {
        if (document.activeElement === lastElement) {
          e.preventDefault()
          firstElement?.focus()
        }
      }
    }

    firstElement?.focus()
    document.addEventListener('keydown', handleTab)
    return () => document.removeEventListener('keydown', handleTab)
  }, [isActive])

  return containerRef
}
```

### Accessible Form Pattern

```tsx
function LoginForm() {
  const [errors, setErrors] = useState<Record<string, string>>({})
  const errorSummaryRef = useRef<HTMLDivElement>(null)

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    const newErrors = validate(formData)
    setErrors(newErrors)

    if (Object.keys(newErrors).length > 0) {
      errorSummaryRef.current?.focus()
    }
  }

  return (
    <form onSubmit={handleSubmit} noValidate>
      {Object.keys(errors).length > 0 && (
        <div ref={errorSummaryRef} role="alert" tabIndex={-1} aria-label="Form errors">
          <h2>Please fix the following errors:</h2>
          <ul>
            {Object.entries(errors).map(([field, message]) => (
              <li key={field}>
                <a href={`#${field}`}>{message}</a>
              </li>
            ))}
          </ul>
        </div>
      )}

      <div>
        <label htmlFor="email">Email address</label>
        <input
          id="email"
          type="email"
          aria-invalid={!!errors.email}
          aria-describedby={errors.email ? 'email-error' : undefined}
        />
        {errors.email && <span id="email-error" role="alert">{errors.email}</span>}
      </div>

      <button type="submit">Sign in</button>
    </form>
  )
}
```

### Live Region for Dynamic Content

```tsx
function SearchResults({ results, loading }: { results: Item[]; loading: boolean }) {
  return (
    <>
      {/* Announce result count to screen readers */}
      <div aria-live="polite" aria-atomic="true" className="sr-only">
        {loading ? 'Searching...' : `${results.length} results found`}
      </div>

      <ul role="list">
        {results.map(item => (
          <li key={item.id}>{item.name}</li>
        ))}
      </ul>
    </>
  )
}
```

---

## Performance Patterns

### React Compiler (Default in 2025+)

React Compiler automatically memoizes components, hooks, and expressions. With Compiler enabled, **most manual memoization is unnecessary**:

```tsx
// With React Compiler enabled, this is automatically optimized:
function ItemList({ items }: { items: Item[] }) {
  const sorted = items.toSorted((a, b) => a.name.localeCompare(b.name))
  const handleSelect = (id: string) => setSelectedId(id)

  return sorted.map(item => (
    <ItemRow key={item.id} item={item} onSelect={handleSelect} />
  ))
}
// Compiler auto-memoizes sorted, handleSelect, and ItemRow renders

// You do NOT need to add React.memo, useMemo, or useCallback here.
// The Compiler handles it.
```

### When Manual Optimization Is Still Needed

React Compiler can't optimize everything. Use manual memoization for:

```tsx
// 1. Expensive computations the compiler can't analyze (external libraries)
const chartData = useMemo(() => processTimeSeriesData(rawData, windowSize), [rawData, windowSize])

// 2. Refs used as stable identity for external subscriptions
const callbackRef = useRef(onUpdate)
useEffect(() => { callbackRef.current = onUpdate })

// 3. Intentional referential identity for third-party libraries
const mapOptions = useMemo(() => ({ center, zoom, style: mapStyle }), [center, zoom, mapStyle])
```

### Lift Constants Outside Components

This optimization applies regardless of React Compiler:

```tsx
// GOOD: Defined once at module scope
const EMPTY_ARRAY: Item[] = []
const DEFAULT_STYLE = { display: 'flex', gap: '1rem' } as const
const SORT_OPTIONS = ['name', 'date', 'price'] as const

function ItemList({ items = EMPTY_ARRAY }: { items?: Item[] }) {
  // ...
}

// BAD: New reference every render
function ItemList({ items = [] }: { items?: Item[] }) {
  const style = { display: 'flex', gap: '1rem' } // New object every render
}
```

### Lazy Loading Heavy Components

```tsx
import { lazy, Suspense } from 'react'

// Split heavy components into separate chunks
const MarkdownEditor = lazy(() => import('./MarkdownEditor'))
const ChartDashboard = lazy(() => import('./ChartDashboard'))
const PDFViewer = lazy(() => import('./PDFViewer'))

function App() {
  const [activeTab, setActiveTab] = useState('editor')

  return (
    <Suspense fallback={<Skeleton />}>
      {activeTab === 'editor' && <MarkdownEditor />}
      {activeTab === 'charts' && <ChartDashboard />}
      {activeTab === 'pdf' && <PDFViewer />}
    </Suspense>
  )
}
```

### Bundle Size Discipline

```tsx
// BAD: Import entire library
import _ from 'lodash'
_.debounce(fn, 300)

// GOOD: Import specific function
import debounce from 'lodash/debounce'
debounce(fn, 300)

// BETTER: Use native when possible
// lodash.debounce → 1.4kb, hand-rolled → 10 lines
function debounce<T extends (...args: unknown[]) => void>(fn: T, ms: number): T {
  let timer: ReturnType<typeof setTimeout>
  return ((...args: unknown[]) => {
    clearTimeout(timer)
    timer = setTimeout(() => fn(...args), ms)
  }) as T
}
```

---

## State Management Decision Tree

| Scenario | Solution |
|----------|----------|
| Toggle, input value, local UI | `useState` |
| Complex state with multiple transitions | `useReducer` |
| Theme, locale, auth (low frequency) | `Context` |
| High-frequency shared state (filters, selections) | Zustand or Jotai |
| Server data (fetching, caching, sync) | TanStack Query or SWR |
| Form state with validation | Native `<form>` + `useActionState` + Zod |
| URL state (search params, pagination) | `useSearchParams` / `nuqs` |
| Complex multi-step wizard forms | React Hook Form + Zod (exception, not default) |

---

## File Organization (Feature-Based)

Organize by **feature/domain**, not by type. Co-locate related code:

```
src/
├── app/                          # Next.js App Router
│   ├── (auth)/                   # Route groups
│   │   ├── login/page.tsx
│   │   └── register/page.tsx
│   ├── dashboard/
│   │   ├── page.tsx              # Server Component
│   │   ├── loading.tsx
│   │   ├── error.tsx
│   │   └── _components/          # Route-specific components
│   │       └── DashboardChart.tsx
│   ├── api/
│   │   └── posts/route.ts
│   ├── layout.tsx
│   └── globals.css
├── features/                     # Feature-based modules
│   ├── users/
│   │   ├── components/           # User-related components
│   │   ├── hooks/                # User-related hooks
│   │   ├── api.ts                # User API calls / query keys
│   │   ├── types.ts              # User types
│   │   ├── utils.ts              # User-specific utilities
│   │   ├── __tests__/            # Tests co-located with feature
│   │   └── index.ts              # Public API (only export what others need)
│   ├── posts/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── api.ts
│   │   └── index.ts
│   └── notifications/
│       └── ...
├── shared/                       # Truly shared across features
│   ├── components/ui/            # Reusable primitives (Button, Input, Modal)
│   ├── hooks/                    # Generic hooks (useToggle, useMeasure)
│   ├── lib/                      # Utilities, API client, validation helpers
│   └── types/                    # Shared TypeScript types
└── test/
    └── utils.tsx                 # Test helpers, provider wrappers
```

**Rules:**
- Features import from `shared/` and other features' `index.ts` only (never reach into another feature's internals)
- Tests live next to implementation (`__tests__/` or `.test.tsx` co-located)
- Barrel files (`index.ts`) export the public API only — don't re-export everything

---

## Quick Reference: Common Mistakes

| Mistake | Fix |
|---------|-----|
| `useState` + `useEffect` for form submission | Use `useActionState` (React 19) |
| `useEffect` with missing deps | Add all referenced values to dep array |
| Object literal in dep array | Extract to `useMemo` or state |
| `any` type | Use `unknown` + type guard |
| `as` type assertion | Use discriminated union or type guard |
| `<div onClick>` | Use `<button>` or add `role`, `tabIndex`, `onKeyDown` |
| Index as key in dynamic list | Use stable unique ID |
| State for derived values | Compute inline or with `useMemo` |
| `'use client'` on page | Push to leaf interactive components |
| `forwardRef` wrapping | Remove — `ref` is a regular prop in React 19 |
| Console.log left in code | Remove before merge |
| Empty catch block | Log error or show user feedback |
| Manual React.memo everywhere | Trust React Compiler; memo only when profiler confirms need |
| `fireEvent` in tests | Use `userEvent` for realistic interactions |
| `getByTestId` on a button | Use `getByRole('button', { name: /label/i })` |
| Snapshot testing JSX | Test behavior with queries and assertions instead |
| Giant component file | Split by responsibility, <300 lines per file |
| Prop drilling 3+ levels | Use composition, Context, or Zustand |
| Creating promises inside `use()` consumer | Create in parent, pass as prop |
| `useFormStatus` in same component as `<form>` | Move to a child component |
