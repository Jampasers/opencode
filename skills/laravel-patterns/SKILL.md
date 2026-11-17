---
name: laravel-patterns
description: Use when building or reviewing Laravel web apps and REST APIs — structuring controllers, services, actions, and repositories; Eloquent models, relationships, scopes, casts, and eager loading; API resources and pagination; form request validation; JWT auth with tymon/jwt-auth; PHPUnit feature/unit tests and factories; migrations and seeders; exception handling and response envelopes; queues, events, caching, and query performance.
origin: merged from laravel-patterns, laravel-service-repository
---

# Laravel Development Patterns

Structure the app around clear boundaries — controllers → form requests → services/actions → repositories → Eloquent models. Keep controllers thin, put orchestration in services, query logic in repositories, validation in form requests, and IO-heavy work in queues.

**Stack:** Laravel 10+ · PHP 8.1+ · Eloquent ORM · tymon/jwt-auth · MySQL/PostgreSQL · PHPUnit

## When to Use

- Building Laravel web applications or APIs
- Structuring controllers, services, actions, and domain logic
- Working with Eloquent models, relationships, and query performance
- Designing APIs with resources, pagination, and JWT auth
- Adding queues, events, caching, and background jobs

## Project Structure

```
app/
├── Actions/            # Single-purpose use cases
├── Console/
├── Events/
├── Exceptions/         # Custom exception classes
├── Http/
│   ├── Controllers/    # (API/ subfolder for APIs)
│   ├── Middleware/     # JWT middleware
│   ├── Requests/       # Form request validation
│   └── Resources/      # API resources
├── Jobs/
├── Models/
├── Policies/
├── Providers/
├── Repositories/       # Data access layer (Contracts/, Traits/)
├── Services/           # Business logic layer (Contracts/, Traits/)
└── Support/
config/
database/ (factories/, migrations/, seeders/)
resources/ (views/, lang/)
routes/ (api.php, web.php, console.php)
tests/ (Feature/API/, Unit/Services/, Unit/Repositories/)
```

## Controllers → Services → Actions

Keep controllers thin; put orchestration in services and single-purpose use cases in actions.

```php
final class CreateOrderAction
{
    public function __construct(private OrderRepository $orders) {}

    public function handle(CreateOrderData $data): Order
    {
        return $this->orders->create($data);
    }
}

final class OrdersController extends Controller
{
    public function __construct(private CreateOrderAction $createOrder) {}

    public function store(StoreOrderRequest $request): JsonResponse
    {
        $order = $this->createOrder->handle($request->toDto());

        return response()->json([
            'status' => true, 'message' => 'Order created',
            'data' => OrderResource::make($order),
        ], 201);
    }
}
```

### Service Layer

Services own business logic and transactions; controllers only orchestrate I/O.

```php
class ProductService implements ServiceInterface
{
    public function __construct(protected ProductRepository $productRepository) {}

    public function getAll(array $filters = []): LengthAwarePaginator
    {
        return $this->productRepository->paginate($filters);
    }

    public function create(array $data): Product
    {
        DB::beginTransaction();
        try {
            $product = $this->productRepository->create($data);
            Log::info('Product created', ['product_id' => $product->id, 'user_id' => auth()->id()]);
            DB::commit();
            return $product;
        } catch (\Throwable $e) {
            DB::rollBack();
            throw new ServiceException('Failed to create product: ' . $e->getMessage(), 500, $e);
        }
    }

    public function update(int $id, array $data): Product
    {
        DB::beginTransaction();
        try {
            $product = $this->productRepository->update($id, $data);
            DB::commit();
            return $product;
        } catch (\Throwable $e) {
            DB::rollBack();
            throw new ServiceException('Failed to update product: ' . $e->getMessage(), 500, $e);
        }
    }
}
```

Service rules:

1. Never access Eloquent models directly from controllers — go through a service.
2. Use `DB::beginTransaction()` / `commit()` / `rollBack()` for multi-table operations.
3. Throw custom exceptions; let the Handler format responses — don't return error arrays.
4. Log in the service layer, not the controller.
5. Fire events/listeners from services, not controllers.

Service container bindings:

```php
final class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(OrderRepository::class, EloquentOrderRepository::class);
    }
}
```

### Repository Layer

Repositories return data (models, collections, paginators) and contain no business logic.

```php
abstract class BaseRepository implements RepositoryInterface
{
    protected Model $model;

    public function __construct() { $this->model = app($this->model()); }
    abstract protected function model(): string;

    public function paginate(array $filters = [], int $perPage = 15): LengthAwarePaginator
    {
        $query = $this->applyFilters($this->model->newQuery(), $filters);
        return $query->paginate($perPage);
    }

    public function findById(int $id): ?Model { return $this->model->find($id); }

    public function update(int $id, array $data): Model
    {
        $record = $this->findById($id);
        if (!$record) throw new NotFoundException('Record not found');
        $record->update($data);
        return $record->fresh();
    }

    public function delete(int $id): bool
    {
        $record = $this->findById($id);
        if (!$record) throw new NotFoundException('Record not found');
        return $record->delete();
    }

    protected function applyFilters(Builder $query, array $filters): Builder { return $query; }
}

class ProductRepository extends BaseRepository
{
    protected function model(): string { return Product::class; }

    protected function applyFilters(Builder $query, array $filters): Builder
    {
        if (!empty($filters['search'])) {
            $query->where(fn ($q) => $q->where('name', 'like', "%{$filters['search']}%")
                ->orWhere('sku', 'like', "%{$filters['search']}%"));
        }
        if (!empty($filters['category_id'])) $query->where('category_id', $filters['category_id']);
        if (!empty($filters['with'])) $query->with($filters['with']);
        return $query;
    }
}
```

Repository rules: no business logic; reuse `applyFilters()` for recurring filters; eager-load via a `with` filter or dedicated methods; return Eloquent types, not arrays.

## Routing

```php
use Illuminate\Support\Facades\Route;

Route::middleware('auth:sanctum')->group(function () {
    Route::apiResource('projects', ProjectController::class);
});

// Scoped bindings prevent cross-tenant access
Route::scopeBindings()->group(function () {
    Route::get('/accounts/{account}/projects/{project}', [ProjectController::class, 'show']);
});

// Explicit model binding for a different class
Route::model('conversation', AiConversation::class);
```

Nested routes: keep prefixes/paths consistent (no `conversation` vs `conversations` mixes), use one parameter name matching the bound model, and prefer scoped bindings to enforce parent-child relationships. Custom binding logic belongs in `Route::bind()` or `resolveRouteBinding()` — and still enforce authorization via policies.

## Eloquent Models

```php
final class Project extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = ['name', 'owner_id', 'status'];
    protected $casts = ['status' => ProjectStatus::class, 'archived_at' => 'datetime'];

    public function owner(): BelongsTo { return $this->belongsTo(User::class, 'owner_id'); }
    public function scopeActive(Builder $query): Builder { return $query->whereNull('archived_at'); }

    protected static function booted(): void
    {
        static::addGlobalScope('active', fn (Builder $b) => $b->whereNull('archived_at'));
    }
}
```

Relationships: `hasOne`/`belongsTo` (one-to-one), `hasMany`/`belongsTo` (one-to-many), `belongsToMany(...)->withTimestamps()->withPivot('quantity')`, `hasManyThrough`, `morphMany`/`morphTo`.

Scopes: local (`scopeActive`, `scopeInStock`, `scopePriceRange`, `scopeSearch` — chainable `Product::active()->inStock()->priceRange(...)`), or a dedicated `Scope` class registered with `static::addGlobalScope(new ActiveScope)`. Use either a global scope or a named scope for the same filter, not both, unless layering is intended.

Accessors/mutators — prefer casts; use `Attribute` for value objects:

```php
protected $casts = ['price' => 'decimal:2', 'is_active' => 'boolean', 'metadata' => 'array', 'published_at' => 'datetime:Y-m-d'];

protected function budgetCents(): Attribute
{
    return Attribute::make(
        get: fn (int $value) => Money::fromCents($value),
        set: fn (Money $money) => $money->toCents(),
    );
}
```

### Eager Loading (prevent N+1)

```php
// BAD — one query per iteration
$orders = Order::all();
foreach ($orders as $order) { echo $order->user->name; }

// GOOD
$orders = Order::with('user', 'items.product')->get();

// Nested, constrained, deferred
Order::with(['user' => fn ($q) => $q->select('id', 'name', 'email'), 'items.product.category'])->get();
Post::with(['comments' => fn ($q) => $q->where('is_approved', true)->latest()])->get();
$orders->load('user', 'items.product');               // lazy eager loading

class Product extends Model { protected $with = ['category']; }  // always loaded

Category::withCount('products')->get();               // $category->products_count
Product::has('tags', '>=', 3)->get();
Product::whereHas('reviews', fn ($q) => $q->where('rating', '>=', 4))->get();
```

Query objects for complex filters — clone the builder per filter (`ownedBy()`, `active()`, `builder()`).

Transactions for multi-step updates:

```php
DB::transaction(function (): void {
    $order->update(['status' => 'paid']);
    $order->items()->update(['paid_at' => now()]);
});
```

## Validation (Form Requests)

Keep validation in form requests and transform to DTOs. Never put business logic in a form request.

```php
final class StoreOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->can('create', Order::class) ?? false;
    }

    public function rules(): array
    {
        return [
            'customer_id' => ['required', 'integer', 'exists:customers,id'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.sku' => ['required', 'string'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
        ];
    }

    protected function prepareForValidation(): void
    {
        $this->merge(['slug' => $this->slug ?? str($this->name)->slug()]);
    }

    public function toDto(): CreateOrderData
    {
        return new CreateOrderData(
            customerId: (int) $this->validated('customer_id'),
            items: $this->validated('items'),
        );
    }
}
```

Update requests: use `sometimes` so only sent fields are validated, and `Rule::unique('products')->ignore($this->route('product'))`. Custom messages go in `messages()`.

Rules: `sometimes` for PATCH/PUT; `Rule::unique()->ignore($id)`; normalize in `prepareForValidation()`; `authorize()` for gate/policy checks; validation only — no business logic.

## REST API

```php
// routes/api.php
Route::post('auth/login', [AuthController::class, 'login']);
Route::post('auth/register', [AuthController::class, 'register']);

Route::middleware('auth:api')->group(function () {
    Route::get('auth/me', [AuthController::class, 'me']);
    Route::post('auth/logout', [AuthController::class, 'logout']);
    Route::post('auth/refresh', [AuthController::class, 'refresh']);
    Route::apiResource('products', ProductController::class);
});
```

Resource controller with consistent envelope (`{ status, message, data?, meta? }`):

```php
class ProductController extends Controller
{
    public function __construct(protected ProductService $productService) {}

    public function index(): JsonResponse
    {
        $products = $this->productService->getAll(request()->all());
        return $this->successResponse(ProductResource::collection($products), meta: [
            'current_page' => $products->currentPage(),
            'last_page' => $products->lastPage(),
            'per_page' => $products->perPage(),
            'total' => $products->total(),
        ]);
    }

    public function store(StoreProductRequest $request): JsonResponse
    {
        $product = $this->productService->create($request->validated());
        return $this->successResponse(new ProductResource($product), 'Product created', 201);
    }

    public function destroy(int $id): JsonResponse
    {
        $this->productService->delete($id);
        return $this->successResponse(null, 'Product deleted');
    }

    protected function successResponse(mixed $data, string $message = 'OK', int $code = 200, ?array $meta = null): JsonResponse
    {
        $response = ['status' => true, 'message' => $message, 'data' => $data];
        if ($meta) $response['meta'] = $meta;
        return response()->json($response, $code);
    }

    protected function errorResponse(string $message, int $code = 400, ?array $errors = null): JsonResponse
    {
        $response = ['status' => false, 'message' => $message];
        if ($errors) $response['errors'] = $errors;
        return response()->json($response, $code);
    }
}
```

API Resource — expose only what the client needs and guard relations with `whenLoaded()`:

```php
class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'price' => (float) $this->price,
            'formatted_price' => $this->formatted_price,
            'category' => new CategoryResource($this->whenLoaded('category')),
            'tags' => TagResource::collection($this->whenLoaded('tags')),
            'created_at' => $this->created_at->toISOString(),
        ];
    }
}
```

Paginated shape: `{ success, data: [...], error, meta: { page, per_page, total } }` or the `{ status, message, data, meta }` variant — pick one and stay consistent.

## JWT Auth (tymon/jwt-auth)

```bash
composer require tymon/jwt-auth:^2.0
php artisan vendor:publish --provider="Tymon\JWTAuth\Providers\LaravelServiceProvider"
php artisan jwt:secret
```

User model implements `JWTSubject`:

```php
class User extends Authenticatable implements JWTSubject
{
    protected $fillable = ['name', 'email', 'password', 'phone', 'avatar'];
    protected $hidden = ['password', 'remember_token'];

    public function getJWTIdentifier(): mixed { return $this->getKey(); }
    public function getJWTCustomClaims(): array { return ['role' => $this->role, 'guard' => 'api']; }
}
```

Config (`config/jwt.php`): `'ttl' => env('JWT_TTL', 60)` minutes, `'refresh_ttl' => env('JWT_REFRESH_TTL', 20160)` (14 days), `'blacklist_enabled' => env('JWT_BLACKLIST_ENABLED', true)`.

```php
class AuthController extends Controller
{
    public function __construct(protected AuthService $authService) {}

    public function login(LoginRequest $request): JsonResponse
    {
        $token = $this->authService->attemptLogin($request->only('email', 'password'));
        if (!$token) return response()->json(['status' => false, 'message' => 'Invalid credentials'], 401);
        return $this->respondWithToken($token);
    }

    public function register(RegisterRequest $request): JsonResponse
    {
        $user = $this->authService->register($request->validated());
        $token = auth('api')->login($user);
        return response()->json([
            'status' => true, 'message' => 'User registered successfully',
            'data' => ['user' => new UserResource($user), 'token' => $token,
                'token_type' => 'bearer', 'expires_in' => auth('api')->factory()->getTTL() * 60],
        ], 201);
    }

    public function me(): JsonResponse
    {
        return response()->json(['status' => true, 'data' => new UserResource(auth('api')->user())]);
    }

    public function logout(): JsonResponse
    {
        auth('api')->logout();
        return response()->json(['status' => true, 'message' => 'Successfully logged out']);
    }

    public function refresh(): JsonResponse { return $this->respondWithToken(auth('api')->refresh()); }

    protected function respondWithToken(string $token): JsonResponse
    {
        return response()->json(['status' => true, 'message' => 'OK', 'data' => [
            'token' => $token, 'token_type' => 'bearer',
            'expires_in' => auth('api')->factory()->getTTL() * 60,
        ]]);
    }
}
```

Middleware maps token errors to 401s:

```php
class JwtMiddleware
{
    public function handle($request, Closure $next)
    {
        try {
            $user = JWTAuth::parseToken()->authenticate();
            if (!$user) return response()->json(['status' => false, 'message' => 'User not found'], 404);
        } catch (TokenExpiredException $e) {
            return response()->json(['status' => false, 'message' => 'Token has expired'], 401);
        } catch (TokenInvalidException $e) {
            return response()->json(['status' => false, 'message' => 'Token is invalid'], 401);
        } catch (JWTException $e) {
            return response()->json(['status' => false, 'message' => 'Token not provided'], 401);
        }
        return $next($request);
    }
}

// Laravel 10: $routeMiddleware['jwt.verify'] = JwtMiddleware::class;
// Laravel 11: $middleware->alias(['jwt.verify' => JwtMiddleware::class]);
```

Rules: use `auth('api')->user()`; always set `JWT_TTL`; never store tokens in the DB (JWT is stateless); rotate with `jwt:secret`; logout = blacklist token (blacklist must be enabled).

## Migrations & Seeders

- Filenames use timestamps: `YYYY_MM_DD_HHMMSS_create_users_table.php`; anonymous classes; `snake_case` plural tables.

```php
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->constrained()->cascadeOnDelete();
            $table->string('name', 255);
            $table->string('slug', 255)->unique();
            $table->text('description')->nullable();
            $table->decimal('price', 12, 2);
            $table->integer('stock')->default(0);
            $table->boolean('is_active')->default(true);
            $table->json('metadata')->nullable();
            $table->softDeletes();
            $table->timestamps();
            $table->index('is_active');
            $table->index(['category_id', 'is_active']);
            $table->fullText(['name', 'description']);
        });
    }

    public function down(): void { Schema::dropIfExists('products'); }
};
```

| Column | Pattern |
|--------|---------|
| ID | `$table->id()` |
| FK | `$table->foreignId('user_id')->constrained()->cascadeOnDelete()` |
| String / Unique | `$table->string('name', 255)` / `->unique()` |
| Text | `$table->text('description')->nullable()` |
| Decimal | `$table->decimal('price', 12, 2)` |
| Boolean | `$table->boolean('is_active')->default(true)` |
| JSON | `$table->json('metadata')->nullable()` |
| Timestamps / Soft delete | `$table->timestamps()` / `$table->softDeletes()` |
| Index / Composite / Fulltext | `$table->index('col')` / `$table->index(['a','b'])` / `$table->fullText(['a','b'])` |

Pivot tables: both FKs `constrained()->cascadeOnDelete()`, plus `$table->unique(['product_id', 'tag_id'])`.

Seeders: call child seeders from `DatabaseSeeder::run()`; hardcode master data (roles, categories), use factories for dummy data (`Product::factory()->count(50)->create(...)`). Run with `php artisan db:seed`, `db:seed --class=ProductSeeder`, or `migrate:fresh --seed`.

Rules: always define `down()`; prefer `foreignId()->constrained()`; index WHERE/ORDER BY/JOIN columns; `softDeletes()` for important data.

## Error Handling

Centralize API exception rendering in `app/Exceptions/Handler.php`:

```php
public function render($request, Throwable $e)
{
    if ($request->expectsJson() || $request->is('api/*')) {
        return $this->renderApiException($e);
    }
    return parent::render($request, $e);
}

protected function renderApiException(Throwable $e): JsonResponse
{
    if ($e instanceof ModelNotFoundException || $e instanceof NotFoundHttpException) {
        return response()->json(['status' => false, 'message' => 'Resource not found'], 404);
    }
    if ($e instanceof ValidationException) {
        return response()->json(['status' => false, 'message' => 'Validation failed', 'errors' => $e->errors()], 422);
    }
    if ($e instanceof \Illuminate\Auth\AuthenticationException) {
        return response()->json(['status' => false, 'message' => 'Unauthenticated'], 401);
    }
    if ($e instanceof AuthorizationException) {
        return response()->json(['status' => false, 'message' => 'Forbidden'], 403);
    }
    if ($e instanceof ServiceException) {
        return response()->json(['status' => false, 'message' => $e->getMessage()], $e->getStatusCode());
    }
    if ($e instanceof HttpException) {
        return response()->json(['status' => false, 'message' => $e->getMessage() ?: 'HTTP Error'], $e->getStatusCode());
    }

    Log::error($e->getMessage(), ['file' => $e->getFile(), 'line' => $e->getLine(), 'trace' => $e->getTraceAsString()]);

    if (config('app.debug')) {
        return response()->json(['status' => false, 'message' => $e->getMessage(), 'trace' => $e->getTraceAsString()], 500);
    }
    return response()->json(['status' => false, 'message' => 'Internal server error'], 500);
}
```

Custom exceptions carry their own status code:

```php
class ServiceException extends Exception
{
    protected int $statusCode;
    public function __construct(string $message = 'Service error', int $statusCode = 500, ?\Throwable $previous = null)
    {
        parent::__construct($message, $statusCode, $previous);
        $this->statusCode = $statusCode;
    }
    public function getStatusCode(): int { return $this->statusCode; }
}

class NotFoundException extends Exception { protected int $statusCode = 404; /* ... */ }
class AuthenticationException extends Exception { protected int $statusCode = 401; }
class BusinessRuleException extends Exception { protected int $statusCode = 422; }
```

For request-level consistency you can instead override `failedValidation()` in a base form request and throw an `HttpResponseException` with the envelope — but prefer the Handler if you want the format globally.

Rules: always return `{ status, message, data?, errors? }`; handle specific exceptions in the Handler, not try-catch in every controller; use custom exception classes for business-rule errors; log 500s; never expose stack traces in production.

## Testing (PHPUnit)

```xml
<!-- phpunit.xml -->
<php>
    <env name="APP_ENV" value="testing"/>
    <env name="DB_CONNECTION" value="sqlite"/>
    <env name="DB_DATABASE" value=":memory:"/>
    <env name="CACHE_DRIVER" value="array"/>
    <env name="QUEUE_CONNECTION" value="sync"/>
    <env name="JWT_SECRET" value="testing-secret-key-here"/>
</php>
```

Feature test — authenticate via JWT, assert envelope shape and DB state:

```php
class ProductControllerTest extends TestCase
{
    use RefreshDatabase, WithFaker;

    protected User $user;
    protected string $token;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::factory()->create(['email' => 'test@example.com', 'password' => bcrypt('password')]);
        $this->token = auth('api')->login($this->user);
    }

    public function test_it_can_create_a_product(): void
    {
        $category = Category::factory()->create();

        $response = $this->withHeaders(['Authorization' => "Bearer {$this->token}"])
            ->postJson('/api/products', [
                'name' => 'Test Product', 'slug' => 'test-product',
                'price' => 150000, 'stock' => 10, 'category_id' => $category->id,
            ]);

        $response->assertStatus(201)
            ->assertJson(['status' => true, 'message' => 'Product created'])
            ->assertJsonPath('data.name', 'Test Product');

        $this->assertDatabaseHas('products', ['name' => 'Test Product', 'slug' => 'test-product']);
    }

    public function test_it_validates_required_fields(): void
    {
        $this->withHeaders(['Authorization' => "Bearer {$this->token}"])
            ->postJson('/api/products', [])
            ->assertStatus(422)
            ->assertJsonStructure(['errors' => ['name', 'price', 'category_id']]);
    }

    public function test_it_requires_authentication(): void
    {
        $this->getJson('/api/products')->assertStatus(401);
    }
}
```

Factories with states:

```php
class ProductFactory extends Factory
{
    protected $model = Product::class;

    public function definition(): array
    {
        return [
            'category_id' => Category::factory(),
            'name' => fake()->unique()->words(3, true),
            'slug' => fn (array $attrs) => str($attrs['name'])->slug(),
            'price' => fake()->numberBetween(10000, 1000000),
            'stock' => fake()->numberBetween(0, 100),
            'is_active' => true,
        ];
    }

    public function inactive(): static { return $this->state(fn () => ['is_active' => false]); }
    public function outOfStock(): static { return $this->state(fn () => ['stock' => 0]); }
}
```

Unit-test services with a mocked repository (no DB):

```php
$mockRepo = $this->mock(ProductRepository::class, function (MockInterface $mock) use ($data) {
    $mock->shouldReceive('create')->once()->with($data)->andReturn(new Product($data));
});
$service = new ProductService($mockRepo);
```

Rules: `RefreshDatabase` for feature tests; test each endpoint for success, validation failure, 404, and 401; mock repositories in service unit tests; use `assertJsonStructure()` for shape and `assertJsonPath()` for values; `php artisan test --parallel` (ParaTest) for speed.

## Performance

Detect N+1:

```bash
composer require beyondcode/laravel-query-detector --dev
```

```php
// Non-production slow-query log
DB::listen(function ($query) {
    if ($query->time > 100) logger()->warning('Slow query: ' . $query->sql, $query->bindings);
});
```

Caching — cache expensive reads, invalidate on writes:

```php
$product = Cache::remember("product:slug:{$slug}", 3600, fn () =>
    Product::with('category', 'tags')->where('slug', $slug)->first());

// On update: forget precise keys and flush tags
Cache::forget("product:{$id}");
Cache::forget("product:slug:{$product->slug}");
Cache::tags(['products'])->flush();   // Redis/Memcached only
```

Query optimization:

```php
User::select('id', 'name', 'email')->get();           // not User::all()
Product::chunk(100, fn ($products) => /* ... */);      // large datasets
foreach (Product::cursor() as $product) { /* ... */ }  // lowest memory
Product::simplePaginate(15);                            // no COUNT
Product::cursorPaginate(15);                            // keyset pagination

// whereHas instead of loading everything
User::whereHas('posts', fn ($q) => $q->where('is_published', true))->with('posts')->get();

// exists() instead of count() > 0
if (Product::where('category_id', $id)->exists()) { /* ... */ }

// Raw expressions for complex SQL
Product::selectRaw('*, (price * (1 - COALESCE(discount, 0) / 100)) as final_price')->get();
```

Checklist: eager-load all relationships used in a request; select only needed columns; paginate every listing; cache frequent reads and invalidate on writes; index WHERE/ORDER BY/JOIN columns; preload relations before passing to views; chunk large processing; minimize queries per request; avoid `toArray()` on huge collections.

## Events, Jobs, and Queues

- Emit domain events for side effects (emails, analytics).
- Queue slow work (reports, exports, webhooks) with idempotent handlers, retries, and backoff.
- Cache read-heavy endpoints and expensive queries; invalidate on model events; use tags for related data.

## Configuration and Environments

- Keep secrets in `.env` and config in `config/*.php`; use per-environment overrides and `config:cache` in production.

## Quick Reference

```bash
# JWT setup
composer require tymon/jwt-auth:^2.0
php artisan vendor:publish --provider="Tymon\JWTAuth\Providers\LaravelServiceProvider"
php artisan jwt:secret

# Scaffolding
php artisan make:model Product -m
php artisan make:controller API/ProductController --api
php artisan make:request StoreProductRequest
php artisan make:resource ProductResource
php artisan make:seeder ProductSeeder
php artisan make:factory ProductFactory
php artisan make:test 'Feature/API/ProductControllerTest'

# Database
php artisan migrate:fresh --seed
php artisan db:seed --class=ProductSeeder

# Testing
php artisan test --filter=ProductControllerTest
php artisan test --testsuite=Feature --stop-on-failure
php artisan test --parallel

# Optimization
php artisan optimize
php artisan route:cache
php artisan config:cache
php artisan view:cache
```
