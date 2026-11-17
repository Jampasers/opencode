---
name: node-express-prisma
description: Use when building or reviewing Node.js/TypeScript backends — Express 5 route/controller/service/DTO structure, response envelopes, class-validator DTOs, Prisma schema/migration/transaction workflows, JWT auth and RBAC, centralized error handling, API design (REST resources, repository/service layers, Next.js API routes), N+1 prevention, Redis caching, rate limiting, background jobs, structured logging, and Vitest/Supertest testing.
origin: merged from node-express-prisma, backend-patterns
---

# Node Express Prisma

Build REST APIs with Express 5, Prisma ORM, PostgreSQL, JWT auth, class-validator DTOs, a single response envelope, and Vitest/Supertest tests. Layer it: routes → middleware (validate/auth) → controllers → services → Prisma.

## When to Use

- Building a new REST API endpoint
- Changing the database schema or migrations
- Implementing auth, authorization, or validation
- Writing integration/unit tests
- Refactoring controllers, services, or routes
- Designing backend structure for Node.js, Express, or Next.js API routes

## Project Structure

```
src/
├── routes/             # *.route.ts
├── controllers/        # *.controller.ts
├── dtos/               # *.dto.ts, *.response.dto.ts
├── middlewares/        # *.middleware.ts
├── services/           # Business logic layer
├── utils/              # *.util.ts
├── prisma/             # schema.prisma, migrations/
├── tests/              # Vitest test files
├── app.ts              # Express app setup
└── server.ts           # Entry point (listen)
```

| File type | Pattern | Example |
|-----------|---------|---------|
| Request DTO | `*.dto.ts` | `create-user.dto.ts` |
| Response DTO | `*.response.dto.ts` | `user.response.dto.ts` |
| Controller | `*.controller.ts` | `user.controller.ts` |
| Route | `*.route.ts` | `user.route.ts` |
| Middleware | `*.middleware.ts` | `auth.middleware.ts` |
| Utility | `*.util.ts` | `envelope.util.ts` |

## Response Envelope

Every API response goes through one helper:

```typescript
export interface ApiResponse<T = unknown> {
  success: boolean
  data: T | null
  message: string
  errors?: Record<string, string[]>
  meta?: { page?: number; limit?: number; total?: number; totalPages?: number }
}

export function success<T>(data: T, message = 'OK'): ApiResponse<T> {
  return { success: true, data, message }
}

export function paginated<T>(data: T[], meta: { page: number; limit: number; total: number }, message = 'OK'): ApiResponse<T[]> {
  return { success: true, data, message, meta: { ...meta, totalPages: Math.ceil(meta.total / meta.limit) } }
}

export function error(message: string, errors?: Record<string, string[]>): ApiResponse<null> {
  return { success: false, data: null, message, errors }
}
```

Rules: `success: true/false`; `data` is the payload or `null` on error; `errors` only for field-level validation; `meta` only for pagination.

## DTOs with class-validator

```typescript
export class CreateUserDto {
  @IsString() @MinLength(3) @MaxLength(50) name!: string
  @IsEmail() email!: string
  @IsString() @MinLength(8) password!: string
}

export class UserResponseDto {
  @Expose() id!: string
  @Expose() name!: string
  @Expose() email!: string
  @Expose() createdAt!: Date
  @Expose() @Transform(() => undefined) password?: never   // never expose
}
```

Validation middleware:

```typescript
export function validateDto(dtoClass: ClassConstructor<unknown>, source: 'body' | 'query' | 'params' = 'body') {
  return async (req: Request, res: Response, next: NextFunction) => {
    const dtoObj = plainToInstance(dtoClass, req[source])
    const errors: ValidationError[] = await validate(dtoObj as object)

    if (errors.length > 0) {
      const formatted: Record<string, string[]> = {}
      for (const err of errors) formatted[err.property!] = Object.values(err.constraints!)
      return res.status(400).json(error('Validation failed', formatted))
    }

    req[source] = dtoObj
    next()
  }
}
```

Serialize responses with `plainToInstance(UserResponseDto, user, { excludeExtraneousValues: true })`.

## Controller Pattern

Controllers only call services, map responses, and delegate errors.

```typescript
export class UserController {
  async create(req: Request, res: Response, next: NextFunction) {
    try {
      const user = await userService.create(req.body as CreateUserDto)
      const response = plainToInstance(UserResponseDto, user, { excludeExtraneousValues: true })
      return res.status(201).json(success(response, 'User created'))
    } catch (err) {
      next(err) // delegate to global error handler
    }
  }

  async findAll(req: Request, res: Response, next: NextFunction) {
    try {
      const page = Number(req.query.page) || 1
      const limit = Number(req.query.limit) || 10
      const { data, total } = await userService.findAll(page, limit)
      const response = data.map(u => plainToInstance(UserResponseDto, u, { excludeExtraneousValues: true }))
      return res.status(200).json(paginated(response, { page, limit, total }, 'Users fetched'))
    } catch (err) {
      next(err)
    }
  }

  async findById(req: Request, res: Response, next: NextFunction) {
    try {
      const user = await userService.findById(req.params.id)
      if (!user) return res.status(404).json(error('User not found'))
      const response = plainToInstance(UserResponseDto, user, { excludeExtraneousValues: true })
      return res.status(200).json(success(response, 'User fetched'))
    } catch (err) {
      next(err)
    }
  }
}
```

## Route Registration

```typescript
const router = Router()
const controller = new UserController()

router.post('/users', validateDto(CreateUserDto), controller.create)          // public
router.get('/users', authMiddleware, controller.findAll)                       // protected
router.get('/users/:id', authMiddleware, controller.findById)
export default router
```

Rules: explicit routes before parameterized routes; auth middleware before handlers; validation middleware per route; keep registration explicit and readable.

## App & Server Setup

```typescript
const app = express()
app.use(express.json())
app.use('/api/v1', userRoutes)
app.use(errorHandler)   // must be after routes
export default app
```

```typescript
const prisma = new PrismaClient()
const PORT = process.env.PORT || 3000

async function main() {
  await prisma.$connect()
  app.listen(PORT, () => console.log(`Server running on port ${PORT}`))
}
main().catch((e) => { console.error(e); process.exit(1) })
```

## Global Error Handler

```typescript
export class AppError extends Error {
  constructor(public statusCode: number, public override message: string, public errors?: Record<string, string[]>) {
    super(message)
  }
}

export function errorHandler(err: Error, _req: Request, res: Response, _next: NextFunction) {
  console.error('[ErrorHandler]', err)

  if (err instanceof AppError) return res.status(err.statusCode).json(error(err.message, err.errors))

  if (err.constructor?.name === 'PrismaClientKnownRequestError') {
    const prismaErr = err as any
    if (prismaErr.code === 'P2002') return res.status(409).json(error('Resource already exists'))
    if (prismaErr.code === 'P2025') return res.status(404).json(error('Resource not found'))
  }

  // If using Zod: return 400 with error.errors

  return res.status(500).json(error('Internal server error'))   // never leak details
}
```

## JWT Auth

```typescript
export interface JwtPayload { userId: string; email: string; role: string }

declare global {
  namespace Express {
    interface Request { user?: JwtPayload }
  }
}

export function authMiddleware(req: Request, _res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization
  if (!authHeader?.startsWith('Bearer ')) throw new AppError(401, 'Missing or invalid authorization header')

  try {
    const secret = process.env.JWT_SECRET
    if (!secret) throw new Error('JWT_SECRET not configured')
    req.user = jwt.verify(authHeader.split(' ')[1], secret) as JwtPayload
    next()
  } catch (err) {
    if (err instanceof AppError) throw err
    throw new AppError(401, 'Invalid or expired token')
  }
}

export function requireRole(...roles: string[]) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!req.user || !roles.includes(req.user.role)) throw new AppError(403, 'Insufficient permissions')
    next()
  }
}

// jwt.util.ts
export function generateToken(payload: Omit<JwtPayload, 'iat' | 'exp'>): string {
  const secret = process.env.JWT_SECRET
  if (!secret) throw new Error('JWT_SECRET not configured')
  return jwt.sign(payload, secret, { expiresIn: '7d' })
}
```

RBAC with a permission map (when roles are not enough):

```typescript
type Permission = 'read' | 'write' | 'delete' | 'admin'
const rolePermissions: Record<User['role'], Permission[]> = {
  admin: ['read', 'write', 'delete', 'admin'],
  moderator: ['read', 'write', 'delete'],
  user: ['read', 'write'],
}
export function hasPermission(user: User, permission: Permission): boolean {
  return rolePermissions[user.role].includes(permission)
}
```

Security checklist: `JWT_SECRET` from env only; token expiry required (default 7d); `Bearer` scheme; don't expose invalid-token details; role guard after `authMiddleware`.

## Prisma Schema & Migration Workflow

```prisma
generator client { provider = "prisma-client-js" }
datasource db { provider = "postgresql"; url = env("DATABASE_URL") }

model User {
  id        String   @id @default(uuid())
  name      String
  email     String   @unique
  password  String
  role      String   @default("user")
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  @@map("users")
}
```

```bash
npx prisma migrate dev --name add_user_table   # create + apply (dev)
npx prisma migrate deploy                       # apply to production
npx prisma generate                             # regenerate client
npx prisma migrate reset                        # development only, destructive
npx prisma db seed
```

Service pattern with Prisma:

```typescript
export class UserService {
  async create(dto: CreateUserDto) {
    const hashedPassword = await bcrypt.hash(dto.password, 12)
    return prisma.user.create({
      data: { name: dto.name, email: dto.email, password: hashedPassword },
      select: { id: true, name: true, email: true, createdAt: true },
    })
  }

  async findAll(page: number, limit: number) {
    const skip = (page - 1) * limit
    const [data, total] = await Promise.all([
      prisma.user.findMany({ skip, take: limit, orderBy: { createdAt: 'desc' } }),
      prisma.user.count(),
    ])
    return { data, total }
  }

  async findByEmail(email: string) {
    return prisma.user.findUnique({ where: { email } })
  }
}

// Multi-step write: atomic
await prisma.$transaction(async (tx) => {
  const user = await tx.user.create({ data: { ... } })
  await tx.profile.create({ data: { userId: user.id, ... } })
  return user
})
```

Database rules: atomic writes for consistency-critical operations; query only needed relations/fields (`select`/`include` explicitly); avoid hidden N+1; use transactions for multi-step writes; index frequently filtered columns.

## Authentication Endpoint

```typescript
router.post('/auth/login', validateDto(LoginDto), controller.login)
router.post('/auth/register', validateDto(CreateUserDto), controller.register)

export class AuthController {
  async login(req: Request, res: Response, next: NextFunction) {
    try {
      const { email, password } = req.body as LoginDto
      const user = await userService.findByEmail(email)
      if (!user || !(await bcrypt.compare(password, user.password))) {
        throw new AppError(401, 'Invalid email or password')
      }
      const token = generateToken({ userId: user.id, email: user.email, role: user.role })
      return res.status(200).json(success({ token, userId: user.id }, 'Login successful'))
    } catch (err) {
      next(err)
    }
  }
}
```

## API Design Patterns

### RESTful Resource URLs

```text
GET    /api/markets                 # List
GET    /api/markets/:id             # Get one
POST   /api/markets                 # Create
PUT    /api/markets/:id             # Replace
PATCH  /api/markets/:id             # Update
DELETE /api/markets/:id             # Delete

GET /api/markets?status=active&sort=volume&limit=20&offset=0   # filter/sort/paginate
```

### Repository Pattern (TypeScript)

Abstract data access so services stay testable:

```typescript
interface MarketRepository {
  findAll(filters?: MarketFilters): Promise<Market[]>
  findById(id: string): Promise<Market | null>
  create(data: CreateMarketDto): Promise<Market>
  update(id: string, data: UpdateMarketDto): Promise<Market>
  delete(id: string): Promise<void>
}

class PrismaMarketRepository implements MarketRepository {
  async findAll(filters?: MarketFilters): Promise<Market[]> {
    return prisma.market.findMany({
      where: { status: filters?.status },
      take: filters?.limit,
    })
  }
}

class MarketService {
  constructor(private marketRepo: MarketRepository) {}
  async searchMarkets(query: string, limit = 10): Promise<Market[]> {
    const results = await this.vectorSearch(await generateEmbedding(query), limit)
    const markets = await this.marketRepo.findByIds(results.map(r => r.id))
    return markets.sort((a, b) => score(a, results) - score(b, results))
  }
}
```

## Database Optimization

```typescript
// GOOD: select only needed columns
await prisma.market.findMany({
  where: { status: 'active' },
  select: { id: true, name: true, status: true, volume: true },
  orderBy: { volume: 'desc' },
  take: 10,
})

// BAD: select everything
await prisma.market.findMany()

// N+1 fix: batch fetch instead of per-row queries
const markets = await getMarkets()
const creatorIds = markets.map(m => m.creator_id)
const creators = await getUsers(creatorIds)          // one query
const creatorMap = new Map(creators.map(c => [c.id, c]))
markets.forEach(m => { m.creator = creatorMap.get(m.creator_id) })
```

Multi-step atomic write via a database function (Supabase RPC style, when the app layer cannot transact):

```sql
CREATE OR REPLACE FUNCTION create_market_with_position(market_data jsonb, position_data jsonb)
RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO markets VALUES (market_data);
  INSERT INTO positions VALUES (position_data);
  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
```

## Caching (Redis Cache-Aside)

```typescript
class CachedMarketRepository implements MarketRepository {
  constructor(private baseRepo: MarketRepository, private redis: RedisClient) {}

  async findById(id: string): Promise<Market | null> {
    const cached = await this.redis.get(`market:${id}`)
    if (cached) return JSON.parse(cached)

    const market = await this.baseRepo.findById(id)
    if (market) await this.redis.setex(`market:${id}`, 300, JSON.stringify(market))
    return market
  }

  async invalidateCache(id: string): Promise<void> {
    await this.redis.del(`market:${id}`)
  }
}
```

Pattern: check cache → miss → fetch DB → `setex` with TTL → return; invalidate on every write.

## Rate Limiting (In-Memory)

```typescript
class RateLimiter {
  private requests = new Map<string, number[]>()

  async checkLimit(identifier: string, maxRequests: number, windowMs: number): Promise<boolean> {
    const now = Date.now()
    const recent = (this.requests.get(identifier) || []).filter(t => now - t < windowMs)
    if (recent.length >= maxRequests) return false
    recent.push(now)
    this.requests.set(identifier, recent)
    return true
  }
}

const allowed = await limiter.checkLimit(ip, 100, 60000)   // 100 req/min per IP
if (!allowed) return NextResponse.json({ error: 'Rate limit exceeded' }, { status: 429 })
```

For multi-instance deployments, back the limiter with Redis instead of process memory.

## Background Jobs

```typescript
class JobQueue<T> {
  private queue: T[] = []
  private processing = false

  async add(job: T): Promise<void> {
    this.queue.push(job)
    if (!this.processing) this.process()
  }

  private async process(): Promise<void> {
    this.processing = true
    while (this.queue.length > 0) {
      const job = this.queue.shift()!
      try { await this.execute(job) } catch (error) { console.error('Job failed:', error) }
    }
    this.processing = false
  }

  private async execute(_job: T): Promise<void> { /* job logic */ }
}
```

Return immediately after enqueueing instead of blocking the request.

## Structured Logging

```typescript
class Logger {
  log(level: 'info' | 'warn' | 'error', message: string, context?: Record<string, unknown>) {
    console.log(JSON.stringify({ timestamp: new Date().toISOString(), level, message, ...context }))
  }
  info(message: string, context?: Record<string, unknown>) { this.log('info', message, context) }
  warn(message: string, context?: Record<string, unknown>) { this.log('warn', message, context) }
  error(message: string, error: Error, context?: Record<string, unknown>) {
    this.log('error', message, { ...context, error: error.message, stack: error.stack })
  }
}
```

Include a `requestId` (`crypto.randomUUID()`) per request; log unexpected errors with stack, respond generically.

## Retry with Exponential Backoff

```typescript
async function fetchWithRetry<T>(fn: () => Promise<T>, maxRetries = 3): Promise<T> {
  let lastError: Error
  for (let i = 0; i < maxRetries; i++) {
    try { return await fn() } catch (error) {
      lastError = error as Error
      if (i < maxRetries - 1) await new Promise(r => setTimeout(r, Math.pow(2, i) * 1000))
    }
  }
  throw lastError!
}
```

## Next.js API Routes

When the backend lives in Next.js route handlers, keep the same envelope and error semantics via higher-order functions:

```typescript
export function withAuth(handler: NextApiHandler): NextApiHandler {
  return async (req, res) => {
    const token = req.headers.authorization?.replace('Bearer ', '')
    if (!token) return res.status(401).json({ success: false, error: 'Unauthorized' })
    try {
      req.user = await verifyToken(token)
      return handler(req, res)
    } catch {
      return res.status(401).json({ success: false, error: 'Invalid token' })
    }
  }
}

export function errorHandler(error: unknown, _request: Request): Response {
  if (error instanceof ApiError) {
    return NextResponse.json({ success: false, error: error.message }, { status: error.statusCode })
  }
  if (error instanceof z.ZodError) {
    return NextResponse.json({ success: false, error: 'Validation failed', details: error.errors }, { status: 400 })
  }
  console.error('Unexpected error:', error)
  return NextResponse.json({ success: false, error: 'Internal server error' }, { status: 500 })
}

// Usage
export async function GET(request: Request) {
  try {
    const user = await requireAuth(request)
    return NextResponse.json({ success: true, data: await getDataForUser(user.userId) })
  } catch (error) {
    return errorHandler(error, request)
  }
}
```

Health check for deploys: add a `/api/health` route returning `{ status: 'ok', timestamp }`.

## Testing (Vitest + Supertest)

```typescript
// vitest.config.ts
export default defineConfig({
  test: { globals: true, environment: 'node', setupFiles: ['./src/tests/setup.ts'], testTimeout: 15000 },
})

// tests/setup.ts
beforeAll(async () => { await prisma.$connect() })
afterEach(async () => { await prisma.user.deleteMany() })
afterAll(async () => { await prisma.$disconnect() })
```

Integration test:

```typescript
const request = supertest(app)

describe('POST /api/v1/users', () => {
  it('creates a user without leaking the password', async () => {
    const res = await request.post('/api/v1/users')
      .send({ name: 'Test User', email: 'test@example.com', password: 'password123' })

    expect(res.status).toBe(201)
    expect(res.body.success).toBe(true)
    expect(res.body.data).toHaveProperty('id')
    expect(res.body.data).not.toHaveProperty('password')
  })

  it('rejects an invalid email', async () => {
    const res = await request.post('/api/v1/users')
      .send({ name: 'Test', email: 'not-an-email', password: 'password123' })
    expect(res.status).toBe(400)
    expect(res.body.errors).toBeDefined()
  })
})

describe('GET /api/v1/users', () => {
  it('requires a token', async () => {
    expect((await request.get('/api/v1/users')).status).toBe(401)
  })

  it('returns the list with a valid token', async () => {
    const login = await request.post('/api/v1/auth/login')
      .send({ email: 'test@example.com', password: 'password123' })
    const res = await request.get('/api/v1/users')
      .set('Authorization', `Bearer ${login.body.data.token}`)
    expect(res.status).toBe(200)
    expect(Array.isArray(res.body.data)).toBe(true)
  })
})
```

Controller unit test: mock the service module with `vi.mock`, pass fake `req`/`res`/`next` objects, assert `res.status` and envelope shape.

```json
"scripts": {
  "test": "vitest run",
  "test:watch": "vitest",
  "test:coverage": "vitest run --coverage",
  "type-check": "tsc --noEmit"
}
```

| Layer | Tools | Focus |
|-------|-------|-------|
| Unit (Service) | Vitest + mock | Business logic, validation, edge cases |
| Unit (DTO) | class-validator | Field validation rules |
| Integration | Vitest + Supertest | Full HTTP request/response cycle |
| E2E (smoke) | Supertest | Critical paths: login, CRUD, auth guard |

Rules: don't test Prisma queries directly in unit tests — mock the service layer; isolate integration tests (`afterEach` cleanup); test 401 without token and 403 without role; assert the envelope shape (`success`, `data`, `message`).

## Endpoint Addition Workflow

1. **DTO**: request DTO (`*.dto.ts`) + response DTO (`*.response.dto.ts`).
2. **Service**: business logic with Prisma queries.
3. **Controller**: handler with standardized success/error + `plainToInstance`.
4. **Route**: register with correct middleware order (validate → auth → handler).
5. **Test**: add an integration test.

Query/list pattern: parse pagination/filter/sort safely from `req.query`; build deterministic `where`/`orderBy`; query + count in parallel with the same filters; return envelope with pagination metadata.

Mutation pattern: validate the payload; check ownership/authorization; run a transaction for multi-step writes; emit log/audit entries for domain-critical changes; return the mapped response DTO.

## Environment Variables

```
DATABASE_URL=postgresql://user:password@localhost:5432/mydb
JWT_SECRET=your-super-secret-key-change-in-production
PORT=3000
NODE_ENV=development
```

Validate all of them at startup.

## Package Dependencies

```json
{
  "dependencies": {
    "express": "^5.0.0", "@prisma/client": "^5.x",
    "class-validator": "^0.14.x", "class-transformer": "^0.5.x",
    "jsonwebtoken": "^9.x", "bcrypt": "^5.x", "reflect-metadata": "^0.2.x"
  },
  "devDependencies": {
    "typescript": "^5.x", "prisma": "^5.x", "vitest": "^1.x", "supertest": "^6.x",
    "@types/express": "^5.x", "@types/jsonwebtoken": "^9.x",
    "@types/bcrypt": "^5.x", "@types/supertest": "^6.x", "tsx": "^4.x"
  }
}
```

TypeScript config essentials: `"target": "ES2022"`, `"strict": true`, `"experimentalDecorators": true`, `"emitDecoratorMetadata": true`, `"esModuleInterop": true`, `"moduleResolution": "node"`.
