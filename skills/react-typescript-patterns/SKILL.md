---
name: react-typescript-patterns
description: Deep reference for React/TypeScript patterns — hooks, components, Next.js App Router, type safety, testing, accessibility, and performance optimization.
origin: claude-react-typescript
---

# React/TypeScript Patterns

Production patterns for React applications with TypeScript. Covers component design, hooks, Next.js App Router, type safety, testing, accessibility, and performance.

## When to Activate

- Building or reviewing React components
- Writing custom hooks
- Working with Next.js App Router (Server Components, Client Components, Server Actions)
- Fixing TypeScript type errors in React code
- Optimizing React performance (re-renders, bundle size, lazy loading)
- Writing tests for React components (React Testing Library, MSW)
- Implementing accessible UI patterns
- Managing state (local, global, server)

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

// Return object for complex hooks
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

// Stable callback ref (avoids stale closures)
function useStableCallback<T extends (...args: unknown[]) => unknown>(callback: T): T {
  const callbackRef = useRef(callback)
  useEffect(() => {
    callbackRef.current = callback
  })
  return useCallback((...args: unknown[]) => callbackRef.current(...args), []) as T
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

## Next.js App Router Patterns

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

### Server Actions

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
  const posts = await db.query(`SELECT * FROM posts ORDER BY ${sort === 'newest' ? 'created_at DESC' : 'likes DESC'} LIMIT $1 OFFSET $2`, [limit, offset])

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

## Testing Patterns

### Component Testing with React Testing Library

```tsx
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { SearchForm } from './SearchForm'

describe('SearchForm', () => {
  it('calls onSearch with debounced input value', async () => {
    const user = userEvent.setup()
    const onSearch = vi.fn()

    render(<SearchForm onSearch={onSearch} />)

    const input = screen.getByRole('searchbox')
    await user.type(input, 'react patterns')

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

### Mocking API Calls with MSW

```tsx
import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'
import { render, screen, waitFor } from '@testing-library/react'
import { UserProfile } from './UserProfile'

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

describe('UserProfile', () => {
  it('renders user data after loading', async () => {
    render(<UserProfile userId="123" />)

    expect(screen.getByText(/loading/i)).toBeInTheDocument()

    await waitFor(() => {
      expect(screen.getByText('Jane Doe')).toBeInTheDocument()
      expect(screen.getByText('jane@example.com')).toBeInTheDocument()
    })
  })

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
})
```

### Testing Async Server Components (Next.js)

```tsx
import { render, screen } from '@testing-library/react'
import DashboardPage from './page'

// Mock the database
vi.mock('@/lib/db', () => ({
  db: {
    query: vi.fn().mockResolvedValue([{ count: 42 }]),
  },
}))

describe('DashboardPage', () => {
  it('renders stats from database', async () => {
    // Server Components are async — await the render
    const Component = await DashboardPage()
    render(Component)

    expect(screen.getByText('42')).toBeInTheDocument()
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
      // Focus the error summary for screen readers
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

### Avoiding Unnecessary Re-renders

```tsx
// Lift constant objects/arrays outside the component
const EMPTY_ARRAY: Item[] = []
const DEFAULT_STYLE = { display: 'flex', gap: '1rem' } as const

function ItemList({ items = EMPTY_ARRAY }: { items?: Item[] }) {
  // Memoize filtered/sorted results
  const sortedItems = useMemo(
    () => [...items].sort((a, b) => a.name.localeCompare(b.name)),
    [items]
  )

  // Stable callback for child components
  const handleSelect = useCallback((id: string) => {
    setSelectedId(id)
  }, [])

  return (
    <div style={DEFAULT_STYLE}>
      {sortedItems.map(item => (
        <MemoizedItem key={item.id} item={item} onSelect={handleSelect} />
      ))}
    </div>
  )
}

const MemoizedItem = React.memo<{ item: Item; onSelect: (id: string) => void }>(
  ({ item, onSelect }) => (
    <button onClick={() => onSelect(item.id)}>{item.name}</button>
  )
)
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

### Optimistic Updates with TanStack Query

```tsx
import { useMutation, useQueryClient } from '@tanstack/react-query'

function useUpdateTodo() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (updated: Todo) => api.updateTodo(updated),

    onMutate: async (updated) => {
      // Cancel in-flight queries
      await queryClient.cancelQueries({ queryKey: ['todos'] })

      // Snapshot previous value
      const previous = queryClient.getQueryData<Todo[]>(['todos'])

      // Optimistically update
      queryClient.setQueryData<Todo[]>(['todos'], old =>
        old?.map(t => t.id === updated.id ? updated : t) ?? []
      )

      return { previous }
    },

    onError: (_err, _updated, context) => {
      // Rollback on error
      queryClient.setQueryData(['todos'], context?.previous)
    },

    onSettled: () => {
      // Refetch to ensure consistency
      queryClient.invalidateQueries({ queryKey: ['todos'] })
    },
  })
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
| Form state with validation | React Hook Form + Zod |
| URL state (search params, pagination) | `useSearchParams` / `nuqs` |

---

## File Organization (Recommended)

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
├── components/
│   ├── ui/                       # Reusable primitives (Button, Input, Modal)
│   ├── forms/                    # Form components
│   └── layouts/                  # Layout components
├── hooks/                        # Custom hooks
├── lib/
│   ├── api.ts                    # API client
│   ├── utils.ts                  # Utility functions
│   └── validations.ts            # Zod schemas
├── types/
│   └── index.ts                  # Shared TypeScript types
└── __tests__/                    # Test files (or co-located .test.tsx)
```

---

## Quick Reference: Common Mistakes

| Mistake | Fix |
|---------|-----|
| `useEffect` with missing deps | Add all referenced values to dep array |
| Object literal in dep array | Extract to `useMemo` or state |
| `any` type | Use `unknown` + type guard |
| `as` type assertion | Use discriminated union or type guard |
| `<div onClick>` | Use `<button>` or add `role`, `tabIndex`, `onKeyDown` |
| Index as key in dynamic list | Use stable unique ID |
| State for derived values | Compute with `useMemo` |
| `'use client'` on page | Push to leaf interactive components |
| Console.log left in code | Remove before merge |
| Empty catch block | Log error or show user feedback |
| Inline function/object on memoized child | Extract to `useCallback`/constant |
| Giant component file | Split by responsibility, <300 lines per file |
