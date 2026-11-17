---
name: react-patterns
description: Use when writing or reviewing React 18/19 components, custom hooks, or component trees; designing state shape and composition; choosing state solutions (Context+Reducer, Zustand) or data fetching (RSC, TanStack Query); building Next.js App Router features (file conventions, Server/Client Components, Server Actions, middleware, error boundaries, loading/Suspense); implementing forms (React 19 actions, React Hook Form + Zod, shadcn/ui); or adding animation, performance, and accessibility patterns.
origin: merged from react-patterns, frontend-patterns, react-nextjs-patterns
---

# React Patterns

Idiomatic React 18/19 and Next.js App Router patterns for building robust, accessible, performant component trees.

## When to Use

- Writing or modifying React function components, custom hooks, or component trees; reviewing JSX/TSX
- Designing state shape or component composition; choosing between local state, lifted state, context, and external stores
- Working with Server Components / Client Components (Next.js App Router, RSC), Server Actions, or file conventions (`page.tsx`, `layout.tsx`, `loading.tsx`, `error.tsx`, `route.ts`, `middleware.ts`)
- Implementing forms with React 19 actions, controlled inputs, or React Hook Form + Zod
- Wiring data fetching with TanStack Query / SWR / RSC
- Migrating class components or older `forwardRef`/`useEffect`-heavy code
- Adding animation (Framer Motion) or accessibility to interactive components

## Core Principles

### 1. Render is a pure function of props and state

```tsx
// Good: derive during render
function Cart({ items }: { items: CartItem[] }) {
  const total = items.reduce((sum, i) => sum + i.price * i.qty, 0);
  return <span>{formatMoney(total)}</span>;
}

// Bad: derived state stored separately
function Cart({ items }: { items: CartItem[] }) {
  const [total, setTotal] = useState(0);
  useEffect(() => {
    setTotal(items.reduce((sum, i) => sum + i.price * i.qty, 0));
  }, [items]);
  return <span>{formatMoney(total)}</span>;
}
```

Derived state in `useEffect` adds a render cycle, can desync, and obscures the data flow.

### 2. Side effects outside render

Effects, mutations, network calls, and subscriptions live in event handlers or `useEffect` — never in the render body.

### 3. Composition over inheritance

React has no inheritance model for components. Compose with `children`, render props, or component props.

## Hooks Discipline

- Top-level only, never conditional
- Cleanup every subscription, interval, listener
- Functional updater (`setX(prev => prev + 1)`) when new state depends on old
- Default position: do not memoize — add `useMemo`/`useCallback` only when a profiler or a dependency chain proves it matters
- Extract a custom hook only when the same hook sequence appears in 2+ components

Common custom hooks:

```tsx
export function useToggle(initialValue = false): [boolean, () => void] {
  const [value, setValue] = useState(initialValue);
  const toggle = useCallback(() => setValue(v => !v), []);
  return [value, toggle];
}

export function useDebounce<T>(value: T, delay = 300): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const id = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(id);
  }, [value, delay]);
  return debounced;
}
```

## State Management

### Where state lives

```
Used by one component?
  -> useState inside it

Used by parent + a few descendants?
  -> lift to nearest common ancestor

Used across distant branches AND low-frequency reads (theme, auth, locale)?
  -> React Context

High-frequency updates shared across the tree?
  -> external store (Zustand, Jotai, Redux Toolkit)

Derived from a server?
  -> server-state library (TanStack Query, SWR, RSC fetch)
```

Most pages do not need context or a global store. Resist abstraction until duplicated lifting becomes painful.

### Context + Reducer (complex local state)

```tsx
type Action =
  | { type: 'SET_MARKETS'; payload: Market[] }
  | { type: 'SELECT_MARKET'; payload: Market }
  | { type: 'SET_LOADING'; payload: boolean };

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'SET_MARKETS': return { ...state, markets: action.payload };
    case 'SELECT_MARKET': return { ...state, selectedMarket: action.payload };
    case 'SET_LOADING': return { ...state, loading: action.payload };
    default: return state;
  }
}

const MarketContext = createContext<{ state: State; dispatch: Dispatch<Action> } | undefined>(undefined);

export function MarketProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(reducer, { markets: [], selectedMarket: null, loading: false });
  return <MarketContext.Provider value={{ state, dispatch }}>{children}</MarketContext.Provider>;
}

export function useMarkets() {
  const context = useContext(MarketContext);
  if (!context) throw new Error('useMarkets must be used within MarketProvider');
  return context;
}
```

### Zustand for client state

Use for UI state (modals, sidebar, filters, preferences), NOT server data (TanStack Query owns that).

```tsx
// lib/stores/ui-store.ts
import { create } from "zustand";
import { persist, devtools } from "zustand/middleware";

export const useUIStore = create<UIState>()(
  persist(
    (set) => ({
      sidebarOpen: true,
      theme: "system",
      toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
      setTheme: (theme) => set({ theme }),
    }),
    { name: "ui-preferences" }
  )
);
```

Use `devtools(...)` wrapper for the cart-style store (items, `addItem` with existing-item merge, `removeItem`, `updateQuantity`, `clearCart` — all via immutable `set`).

Efficient selectors — subscribe to the narrowest derived value:

```tsx
// ❌ re-renders on ANY cart change
const items = useCartStore((s) => s.items);

// ✅ re-renders only when the count changes
const count = useCartStore((s) => s.items.reduce((acc, i) => acc + i.quantity, 0));

// ✅ reusable selector
const selectCartCount = (s: CartState) => s.items.reduce((acc, i) => acc + i.quantity, 0);
const count = useCartStore(selectCartCount);
```

Initialize a store from server data via a provider (per-request store instance, not module global):

```tsx
"use client";
const CartStoreContext = createContext<StoreApi<CartState> | null>(null);

export function CartStoreProvider({ children, initialItems }: { children: ReactNode; initialItems: CartItem[] }) {
  const storeRef = useRef<StoreApi<CartState>>();
  if (!storeRef.current) storeRef.current = createCartStore({ items: initialItems });
  return <CartStoreContext.Provider value={storeRef.current}>{children}</CartStoreContext.Provider>;
}
```

### Data flow decision

```
Server data (DB/external API)
├── Page-level, public → async Server Component + fetch()
└── Interactive, client refetch → TanStack Query

Client UI state
├── Local → useState
├── Few levels → props + lifting
└── Global (sidebar, theme, modals) → Zustand

Form state → React Hook Form + Zod (past trivial complexity)

URL state
├── Search params → useSearchParams() + useRouter().push()
└── Path params → page.tsx `params` prop

Cache
├── Server fetch → fetch() `next.revalidate` / `cache: "force-cache"`
└── Client query → TanStack Query staleTime/gcTime
```

## Server / Client Components (RSC)

**Golden rule:** all components are Server Components by default. Add `'use client'` only when you need browser-only APIs or interactivity.

| Need | Server? | Client? |
|------|---------|---------|
| Fetch data from DB/API (`await fetch()`) | ✅ Default | ❌ |
| Access backend resources (env vars, filesystem) | ✅ | ❌ |
| Event handlers (`onClick`, `onSubmit`) | ❌ | ✅ |
| Hooks (`useState`, `useEffect`, `useContext`) | ❌ | ✅ |
| Browser APIs (`localStorage`, `window`) | ❌ | ✅ |
| Custom hooks with state (`useForm`, `useMediaQuery`) | ❌ | ✅ |
| Pure presentational JSX | ✅ | ✅ (prefer Server) |

```tsx
// Server Component — default, async, never ships JS for itself
export default async function ProductPage({ params }: { params: { id: string } }) {
  const product = await db.product.findUnique({ where: { id: params.id } });
  if (!product) notFound();
  return <ProductView product={product} />;
}

// Client Component — opt in with "use client"
"use client";
export function AddToCartButton({ productId }: { productId: string }) {
  const [pending, startTransition] = useTransition();
  return (
    <button disabled={pending} onClick={() => startTransition(() => addToCart(productId))}>
      {pending ? "Adding..." : "Add to cart"}
    </button>
  );
}
```

Keep business logic on the server; push interactivity to small client leaves:

```tsx
// ✅ Parent: Server Component (fetches data); only the button is a Client Component
async function ProductPage({ id }: { id: string }) {
  const product = await fetchProduct(id);
  return (
    <div>
      <h1>{product.name}</h1>
      <p>{product.description}</p>
      <AddToCart productId={product.id} />
    </div>
  );
}
```

Boundaries and pitfalls:

- Server → Client: pass serializable props or `children`
- Client → Server: invoke Server Actions via `<form action={...}>` or imperatively from event handlers
- Never `import` a Server Component from a Client Component file — compose them via `children` instead
- ❌ Do not put `'use client'` on a component that only renders JSX — it needlessly ships JS

## Next.js App Router — File Conventions

```tsx
// app/products/page.tsx — route UI (Server Component by default; may export metadata/generateMetadata)
export default async function ProductsPage() {
  const products = await fetch("https://api.example.com/products", { next: { revalidate: 60 } });
  return <ProductList products={await products.json()} />;
}

// app/(dashboard)/layout.tsx — shared shell; persists across navigations; Server-only (never 'use client')
export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return <div className="flex h-screen"><Sidebar /><main className="flex-1 p-6">{children}</main></div>;
}

// app/products/loading.tsx — automatic Suspense fallback for the segment
export default function ProductsLoading() {
  return <Skeleton className="h-48" />;
}

// app/products/error.tsx — automatic Error Boundary; MUST be 'use client'
"use client";
export default function ProductsError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return <div><p>{error.message}</p><Button onClick={() => reset()}>Try again</Button></div>;
}

// app/api/products/route.ts — API endpoint; named HTTP method exports
export async function GET(request: NextRequest) {
  const page = Number(request.nextUrl.searchParams.get("page")) || 1;
  return NextResponse.json(await prisma.product.findMany({ skip: (page - 1) * 10, take: 10 }));
}
export async function POST(request: NextRequest) {
  return NextResponse.json(await prisma.product.create({ data: await request.json() }), { status: 201 });
}
```

Dynamic routes: `[id]` single segment, `[...slug]` catch-all, `[[...slug]]` optional catch-all. `params` is a Promise in Next.js 15 — `const { id } = await params`.

| File | Purpose | Server/Client | Exports |
|------|---------|---------------|---------|
| `page.tsx` | Route UI | Server (default) | `default function`, `metadata`/`generateMetadata` |
| `layout.tsx` | Shared shell (persists nav) | Server only | `default function` with `children` |
| `loading.tsx` | Suspense fallback | Server | `default function` |
| `error.tsx` | Error boundary | **Client** | `default function` with `{ error, reset }` |
| `global-error.tsx` | Root error boundary | **Client** | `default function` with `{ error, reset }` (includes `<html>`) |
| `not-found.tsx` | 404 page | Server | `default function` |
| `route.ts` | API endpoint | Server | Named `GET`, `POST`, `PUT`, `PATCH`, `DELETE` |
| `middleware.ts` | Edge request handling | Edge runtime | `default` or `middleware` |
| `template.tsx` | Like layout but re-mounts | Server | `default function` with `children` |
| `default.tsx` | Parallel route fallback | Server | `default function` |

## Server Actions for Mutations

```tsx
// Inline Server Action (in a Server Component)
export default function CreateProductPage() {
  async function createProduct(formData: FormData) {
    "use server";
    await prisma.product.create({ data: { name: formData.get("name") as string, price: Number(formData.get("price")) } });
    revalidatePath("/products");
    redirect("/products");
  }
  return <form action={createProduct}><input name="name" required /><Button type="submit">Create</Button></form>;
}

// Reusable Server Action file — validate with Zod, return structured errors
// lib/actions/products.ts
"use server";
export async function createProduct(prevState: unknown, formData: FormData) {
  const parsed = createProductSchema.safeParse({ name: formData.get("name"), price: Number(formData.get("price")) });
  if (!parsed.success) return { error: parsed.error.flatten().fieldErrors };
  try {
    await prisma.product.create({ data: parsed.data });
  } catch (e) {
    return { error: { _form: ["Failed to create product"] } };
  }
  revalidatePath("/products");
  redirect("/products");
}
```

Call from a Client Component with `useActionState` (React 19; `useFormState` from `react-dom` pre-19):

```tsx
"use client";
const [state, formAction, isPending] = useActionState(createProduct, null);
return (
  <form action={formAction}>
    <Input name="name" />
    {state?.error?.name && <p className="text-destructive">{state.error.name}</p>}
    <Button type="submit" disabled={isPending}>{isPending ? "Creating..." : "Create"}</Button>
  </form>
);
```

| Rule | Detail |
|------|--------|
| **Always validate** | Never trust `formData` — validate with Zod or similar |
| **Auth check first** | Verify user permissions at the top of every action |
| **Revalidate** | Call `revalidatePath` / `revalidateTag` after successful mutations |
| **Redirect after success** | `redirect()` only works in a Server Action, not a Client Component |
| **Pending + errors** | Use `useActionState` (React 19) |
| **Security** | Server Actions are public POST endpoints — protect them like API routes |

## Data Fetching — TanStack Query

| Need | Tool |
|---|---|
| Per-request data in Next.js App Router | RSC `await fetch()` |
| Client-side cache + mutations + invalidation | TanStack Query |
| Lightweight client cache + revalidation | SWR |
| Real-time subscriptions | SSE, WebSockets, or the lib's subscription API |
| One-off fire-and-forget | `fetch()` in an event handler |

Avoid `useEffect` + `fetch` for application data — race conditions, no cache, no retry, no Suspense integration.

### Setup

```tsx
// app/providers.tsx
"use client";
export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: { queries: { staleTime: 60 * 1000, retry: 1, refetchOnWindowFocus: false } },
  }));
  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}
// app/layout.tsx wraps <body> content in <Providers>
```

### useQuery

```tsx
const { data, isLoading, error } = useQuery({
  queryKey: ["products"],
  queryFn: fetchProducts, // throw on !res.ok
  select: (data) => data.sort((a, b) => a.name.localeCompare(b.name)),
});
if (isLoading) return <ProductsSkeleton />;
if (error) return <div>Error: {error.message}</div>;
```

### Pagination — keep previous page while loading

```tsx
const { data, isPlaceholderData } = useQuery({
  queryKey: ["products", page],
  queryFn: () => fetch(`/api/products?page=${page}`).then((r) => r.json()),
  placeholderData: (prev) => prev,
});
// disable Next while isPlaceholderData || !data?.hasMore
```

### useMutation + invalidation

```tsx
const mutation = useMutation({
  mutationFn: deleteProduct,
  onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["products"] }); toast.success("Deleted"); },
  onError: (error) => toast.error(error.message),
});
<Button onClick={() => mutation.mutate(productId)} disabled={mutation.isPending}>Delete</Button>
```

### Optimistic updates — cancel, snapshot, set, rollback, settle

```tsx
onMutate: async (newTodo) => {
  await queryClient.cancelQueries({ queryKey: ["todos"] });
  const previous = queryClient.getQueryData<Todo[]>(["todos"]);
  queryClient.setQueryData<Todo[]>(["todos"], (old) => old?.map((t) => (t.id === newTodo.id ? newTodo : t)));
  return { previous };
},
onError: (_err, _newTodo, context) => { if (context?.previous) queryClient.setQueryData(["todos"], context.previous); },
onSettled: () => queryClient.invalidateQueries({ queryKey: ["todos"] }),
```

### Infinite queries

```tsx
const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteQuery({
  queryKey: ["products-infinite"],
  queryFn: ({ pageParam = 1 }) => fetch(`/api/products?page=${pageParam}`).then((r) => r.json()),
  getNextPageParam: (lastPage, pages) => (lastPage.hasMore ? pages.length + 1 : undefined),
  initialPageParam: 1,
});
```

### Prefetching (avoid waterfalls)

```tsx
// Server Component prefetches; client hydrates the cache
const queryClient = new QueryClient();
await queryClient.prefetchQuery({ queryKey: ["products"], queryFn: fetchProducts });
return <HydrationBoundary state={dehydrate(queryClient)}><ProductsList /></HydrationBoundary>;
```

## Forms

### React 19 form actions (preferred for new code)

```tsx
"use client";
import { useActionState } from "react";

const initial = { error: null as string | null };

async function updateUserAction(_prev: typeof initial, formData: FormData) {
  "use server";
  const parsed = UserSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { error: "Invalid input" };
  await db.user.update({ where: { id: parsed.data.id }, data: parsed.data });
  return { error: null };
}

export function UserForm() {
  const [state, formAction, pending] = useActionState(updateUserAction, initial);
  return (
    <form action={formAction}>
      <input name="name" required />
      <button type="submit" disabled={pending}>Save</button>
      {state.error && <p role="alert">{state.error}</p>}
    </form>
  );
}
```

### Controlled inputs

Use controlled when the value drives other UI, formats on every keystroke, or implements real-time validation. For simple controlled validation, keep the errors map in state and validate on submit (set `errors` from a `validate()` function; render `errors.field` next to each input). For multi-step forms, dynamic field arrays, or cross-field validation use a library — rolling your own past trivial complexity is a maintenance trap.

### React Hook Form + Zod

```bash
npm install react-hook-form @hookform/resolvers zod
```

```tsx
// lib/schemas/product-schema.ts
export const productSchema = z.object({
  name: z.string().min(1, "Name is required").max(100),
  description: z.string().min(10),
  price: z.coerce.number().positive("Price must be positive"),
  category: z.string().min(1),
  published: z.boolean().default(false),
});
export type ProductFormValues = z.infer<typeof productSchema>;

// components/product-form.tsx
"use client";
export function ProductForm({ onSubmit }: { onSubmit: (v: ProductFormValues) => Promise<void> }) {
  const form = useForm<ProductFormValues>({
    resolver: zodResolver(productSchema),
    defaultValues: { name: "", description: "", price: 0, category: "", published: false },
  });

  const handleSubmit = async (values: ProductFormValues) => {
    try { await onSubmit(values); toast.success("Saved"); form.reset(); }
    catch { toast.error("Failed to save"); }
  };

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-6">
        <FormField control={form.control} name="name" render={({ field }) => (
          <FormItem>
            <FormLabel>Product Name</FormLabel>
            <FormControl><Input placeholder="Enter product name" {...field} /></FormControl>
            <FormMessage />
          </FormItem>
        )} />
        <Button type="submit" disabled={form.formState.isSubmitting}>Save</Button>
      </form>
    </Form>
  );
}
```

With Server Actions: pass validated values from the form's `onSubmit` to an action and re-validate server-side (client validation is UX, not security). Dynamic array fields via `useFieldArray({ control, name: "variants" })` → render `fields`, `append`, `remove` per row (`key={field.id}`, register with `variants.${index}.name`).

## shadcn/ui

```bash
npx shadcn@latest init
npx shadcn@latest add button card form input select dialog toast
```

| Component | Usage |
|-----------|-------|
| `Button` | `variant="default\|destructive\|outline\|secondary\|ghost\|link"`, `size="default\|sm\|lg\|icon"` |
| `Card`/`CardHeader`/`CardContent`/`CardFooter` | Layout containers |
| `Input`, `Textarea` | Form text inputs (use in `FormField`) |
| `Select` (+`Trigger`/`Value`/`Content`/`Item`) | Dropdown select (use `onValueChange` in `FormField`) |
| `Dialog` (+`Trigger`/`Content`/`Header`/`Title`/`Description`) | Modal dialogs |
| `Sheet` | Slide-out panels (mobile menus, filters) |
| `Toast` / `Sonner` | `toast.success()`, `toast.error()` |
| `Skeleton` | Loading placeholders |
| `Tabs`/`TabsList`/`TabsTrigger`/`TabsContent` | Tabbed interface |
| `Table` (+`Header`/`Body`/`Row`/`Cell`/`Head`) | Data tables |
| `Badge` | Status/tag badges |
| `DropdownMenu` (+`Trigger`/`Content`/`Item`) | Context/action menus |
| `Avatar` (+`Image`/`Fallback`) | User avatars with fallback initials |
| `Switch` | Toggle switches (boolean fields) |
| `Label`, `Separator` | Form labels, dividers |

Components live in `@/components/ui/` — customize directly (edit `cva` variants in place; add e.g. a `success` button variant). CRUD dialog pattern: `useState` for `open`, `<DialogTrigger asChild><Button>`, form content in `<DialogContent>`, actions in `<DialogFooter>`.

## SEO Metadata (generateMetadata)

```tsx
// Static
export const metadata: Metadata = { title: "About Us | My App", description: "...", openGraph: { title, description, type: "website" } };

// Dynamic
export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params;
  const product = await fetch(`https://api.example.com/products/${id}`).then((r) => r.json());
  if (!product) return {};
  return {
    title: `${product.name} | My Store`,
    description: product.description.slice(0, 160),
    openGraph: { title: product.name, description: product.description.slice(0, 160), images: [{ url: product.image, width: 1200, height: 630 }] },
    twitter: { card: "summary_large_image", images: [product.image] },
    alternates: { canonical: `/products/${product.id}` },
  };
}

// app/layout.tsx — template applies to children
export const metadata: Metadata = {
  title: { default: "My Store", template: "%s | My Store" },
  description: "The best store on the web",
  metadataBase: new URL("https://example.com"),
};
```

JSON-LD in a Server Component: `<script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />` alongside the rendered page. For the full metadata/structured-data/sitemap/robots playbook, see the [seo](../seo/SKILL.md) skill.

## Middleware (Auth & Redirect)

Runs before every matched request (Edge runtime by default): auth checks, redirects, rewrites, headers, geolocation, bot detection.

```tsx
// middleware.ts (project root)
import { NextResponse, type NextRequest } from "next/server";

export function middleware(request: NextRequest) {
  const token = request.cookies.get("session")?.value;
  const isAuthPage = request.nextUrl.pathname.startsWith("/login");
  const isApiAuthRoute = request.nextUrl.pathname.startsWith("/api/auth");

  if (isAuthPage || isApiAuthRoute) {
    if (token && isAuthPage) return NextResponse.redirect(new URL("/dashboard", request.url));
    return NextResponse.next();
  }
  if (!token) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("redirect", request.nextUrl.pathname);
    return NextResponse.redirect(loginUrl);
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)"],
};
```

Multi-role variant: map `ROLES = { admin: ["/admin", "/dashboard"], user: ["/dashboard", "/profile"] }`, resolve the role from a verified JWT, and 302 to `/403` when the path is not in the role's allowlist. Auth.js (NextAuth v5): wrap with `auth((req) => ...)`, return `401` JSON for protected API routes, redirect for pages.

| Rule | Detail |
|------|--------|
| **Use `matcher`** | Always define `config.matcher` — never run middleware on every request |
| **Keep it fast** | Runs on every matched request — avoid heavy computation |
| **JWT verification** | Lightweight library (jose); avoid Prisma/DB calls if possible |
| **Redirects** | `NextResponse.redirect(new URL(...))` — not `redirect()` from `next/navigation` |
| **Headers & cookies** | Set security headers and cookies here |
| **Edge runtime** | No Node.js APIs (fs, crypto) by default |

## Error Boundaries

App Router: `error.tsx` wraps its segment and children; `global-error.tsx` catches root-layout errors (replaces the whole layout, includes `<html>`).

```tsx
// app/products/error.tsx
"use client";
export default function Error({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => { console.error(error); }, [error]); // log to monitoring
  return (
    <div>
      <h2>Something went wrong!</h2>
      <button onClick={() => reset()}>Try Again</button>
      <button onClick={() => (window.location.href = "/")}>Go Home</button>
    </div>
  );
}
```

Fine-grained client boundaries — class API with optional fallback:

```tsx
"use client";
export class ErrorBoundary extends Component<{ children: ReactNode; fallback?: ReactNode }, { hasError: boolean; error: Error | null }> {
  state = { hasError: false, error: null };
  static getDerivedStateFromError(error: Error) { return { hasError: true, error }; }
  componentDidCatch(error: Error, errorInfo: ErrorInfo) { console.error("ErrorBoundary caught:", error, errorInfo); }
  render() {
    if (this.state.hasError) {
      if (this.props.fallback) return this.props.fallback;
      return <div><p>{this.state.error?.message}</p><button onClick={() => this.setState({ hasError: false, error: null })}>Try Again</button></div>;
    }
    return this.props.children;
  }
}
// Usage: <ErrorBoundary fallback={<div>Chart failed to load</div>}><ProductChart /></ErrorBoundary>
```

Hierarchy and rules:

```
global-error.tsx          ← root layout errors (replaces everything)
  └── error.tsx           ← this segment + children
        └── <ErrorBoundary>  ← fine-grained client-side boundaries
```

- A boundary catches errors thrown during render, lifecycle, and constructors of its children — NOT in event handlers or async code
- Use `react-error-boundary` for a hook-friendly wrapper
- `notFound()` from `next/navigation` renders the closest `not-found.tsx` (and returns the correct status)

## Loading & Suspense

```tsx
<Suspense fallback={<UserSkeleton />}>
  <UserDetail id={id} />
</Suspense>
```

- Place Suspense boundaries close to the data, not at the route root — progressively reveal content
- `loading.tsx` automatically wraps the segment in Suspense; add granular `<Suspense>` per section for independent streaming (fast sections paint first)
- Do not lazy-load critical above-the-fold content behind Suspense

```tsx
// Streaming: each async Server Component resolves independently
export default function DashboardPage() {
  return (
    <div>
      <Suspense fallback={<MetricsSkeleton />}><MetricsGrid /></Suspense>
      <div className="grid grid-cols-2 gap-6">
        <Suspense fallback={<ChartSkeleton />}><RevenueChart /></Suspense>
        <Suspense fallback={<SalesSkeleton />}><RecentSales /></Suspense>
      </div>
    </div>
  );
}
```

Loading decision tree:

```
Is the data fetched on the server?
  ├── Yes → async Server Component + Suspense
  │         ├── Individual sections? → granular <Suspense>
  │         └── Whole page? → loading.tsx at the segment
  └── No → TanStack Query on the client
            ├── Initial load → isLoading → skeleton
            ├── Background refetch → isFetching → subtle indicator
            └── Mutation → isPending → disabled button + spinner
```

Client states with TanStack Query: `isLoading` → skeleton; `error` → error UI with `refetch()` retry link; `isFetching` → small background-refetch indicator (keep showing stale data).

## Performance

### When `React.memo` actually helps

Wrap only when: 1) it re-renders frequently, 2) props are usually the same between renders, 3) its render is measurably expensive. `React.memo` adds an equality check on every render — if props differ on most renders, the check is pure overhead. `useMemo` for expensive computations, `useCallback` for functions passed to memoized children — but default to none of them until proven.

```tsx
const sorted = useMemo(() => markets.sort((a, b) => b.volume - a.volume), [markets]);
const handleSearch = useCallback((query: string) => setSearchQuery(query), []);
```

### Avoiding render cascades

- Lift state down rather than up where possible
- Split context: one context per concern, so a change to `themeContext` does not re-render auth consumers
- Use `useSyncExternalStore` for external state libraries — required for safe concurrent rendering

### Lists

- Provide stable `key` props (database id, not array index)
- Virtualize long lists with `@tanstack/react-virtual` or `react-window` once visible item count exceeds ~50 with non-trivial rows

```tsx
const virtualizer = useVirtualizer({
  count: items.length,
  getScrollElement: () => parentRef.current,
  estimateSize: () => 100,
  overscan: 5,
});
// container (overflow: auto) → inner div height = virtualizer.getTotalSize(), position: relative
// rows: key={row.index}, position: absolute, transform: translateY(row.start)
```

### Code splitting & lazy loading

```tsx
const HeavyChart = lazy(() => import("./HeavyChart"));
<div>
  <Suspense fallback={<ChartSkeleton />}><HeavyChart data={data} /></Suspense>
  <Suspense fallback={null}><ThreeJsBackground /></Suspense>
</div>
```

For the full performance ruleset (waterfalls, bundles, re-renders, rendering), see [react-performance](../react-performance/SKILL.md).

## Animation (Framer Motion)

```tsx
import { motion, AnimatePresence } from "framer-motion";

// List animations — exit requires AnimatePresence + stable keys
<AnimatePresence>
  {items.map((item) => (
    <motion.div key={item.id} initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -20 }} transition={{ duration: 0.3 }}>
      <ItemCard item={item} />
    </motion.div>
  ))}
</AnimatePresence>

// Modal: animate overlay (opacity) and content (opacity + scale + y) under one AnimatePresence
<motion.div className="modal-content" initial={{ opacity: 0, scale: 0.9, y: 20 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, scale: 0.9, y: 20 }}>
```

## Accessibility-First Composition

- Always render semantic HTML (`<button>`, `<a>`, `<nav>`, `<main>`) before reaching for `role` attributes
- Every interactive element must be reachable by keyboard
- Form inputs need labels — `<label htmlFor>` or `aria-label` if visually labeled by an icon
- Manage focus on route changes and modal open/close
- Run `axe` in component tests (see [react-testing](../react-testing/SKILL.md))
- Cross-link: [accessibility](../accessibility/SKILL.md) covers WCAG criteria and pattern libraries

Keyboard-navigable combobox: track `activeIndex`, handle `ArrowDown`/`ArrowUp` (clamp within options), `Enter` (select + close), `Escape` (close), and expose `role="combobox"`, `aria-expanded`, `aria-haspopup="listbox"`.

Focus management for modals: on open, save `document.activeElement` and focus the dialog (`tabIndex={-1}`, `role="dialog"`, `aria-modal="true"`); on close, restore focus to the saved element; close on `Escape`.

## Routing

This skill is router-agnostic for React core patterns; they work with React Router, TanStack Router, Next.js App Router, Remix Router. Router-specific patterns (loaders, actions, nested layouts) follow the router's documentation.

## Out of Scope

- **Next.js advanced routing** (parallel/intercepting routes, route groups beyond basics): see Next.js docs
- **React Native**: platform-specific patterns differ enough to warrant a separate skill
- **Remix**: loader/action conventions overlap with RSC but follow Remix docs

## Examples

### Debounced search with TanStack Query

```tsx
function SearchBox() {
  const [query, setQuery] = useState("");
  const debounced = useDebounce(query, 300);
  const { data } = useQuery({
    queryKey: ["search", debounced],
    queryFn: () => searchApi(debounced),
    enabled: debounced.length > 0,
  });
  return (
    <>
      <input value={query} onChange={(e) => setQuery(e.target.value)} />
      <Results items={data ?? []} />
    </>
  );
}
```

### Optimistic UI with React 19 `useOptimistic`

```tsx
"use client";
import { useOptimistic } from "react";

export function MessageList({ messages }: { messages: Message[] }) {
  const [optimistic, addOptimistic] = useOptimistic(messages, (state, newMessage: Message) => [...state, newMessage]);

  async function send(formData: FormData) {
    const text = String(formData.get("text"));
    addOptimistic({ id: "pending", text, sender: "me" });
    await saveMessage(text);
  }

  return (
    <>
      <ul>{optimistic.map((m) => <li key={m.id}>{m.text}</li>)}</ul>
      <form action={send}><input name="text" /><button type="submit">Send</button></form>
    </>
  );
}
```

### Splitting context to avoid render cascades

```tsx
// Two contexts: one rarely changes, one frequently
const ThemeContext = createContext<Theme>("light");
const NotificationsContext = createContext<Notification[]>([]);
// A component consuming only ThemeContext does NOT re-render when notifications change
```

## Related

- Skills: [react-performance](../react-performance/SKILL.md) for the performance ruleset, [seo](../seo/SKILL.md) for metadata/structured data, [accessibility](../accessibility/SKILL.md), [react-testing](../react-testing/SKILL.md)
- Agents: `react-reviewer` for code review, `react-build-resolver` for build/bundler errors
- Commands: `/react-review`, `/react-build`, `/react-test`
