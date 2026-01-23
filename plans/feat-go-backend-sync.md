# feat: Go Backend with Neon DB for Cross-Device Sync

**Status:** Ready for Implementation
**Created:** 2026-01-23
**Scope:** Backend API + iOS Integration (MVP)
**Go Version:** 1.22+ (required for enhanced `net/http` routing)

---

## Overview

Build a Go backend with Neon PostgreSQL to enable **optional cross-device sync** for Memoss. Users can:

1. **Use without account** - Local-only mode (current behavior, no data leaves device)
2. **Create account** - Enable cloud sync across all devices

This architecture supports future Android development while respecting user privacy.

---

## Architecture

```mermaid
sequenceDiagram
    participant iOS as Memoss iOS
    participant Android as Memoss Android (Future)
    participant API as Go Backend
    participant Neon as Neon PostgreSQL
    participant Auth as Auth Provider

    Note over iOS: User chooses "Enable Sync"
    iOS->>Auth: Sign in (Apple/Google)
    Auth-->>iOS: ID Token
    iOS->>API: POST /auth/login {id_token}
    API->>Auth: Verify token
    Auth-->>API: User info
    API->>Neon: Create/get user
    Neon-->>API: User record
    API-->>iOS: JWT access + refresh tokens

    Note over iOS: Sync reminders
    iOS->>API: GET /reminders (Bearer token)
    API->>Neon: SELECT reminders WHERE user_id = ?
    Neon-->>API: Reminder rows
    API-->>iOS: JSON response

    iOS->>API: POST /reminders {reminder}
    API->>Neon: INSERT reminder
    Neon-->>API: Created
    API-->>iOS: 201 Created

    Note over iOS: Real-time updates (future)
    iOS->>API: WebSocket /ws/sync
    API-->>iOS: Push updates
```

---

## Authentication Strategy

### Recommended: Sign in with Apple + Google Sign-In

**Why these providers?**
- **Sign in with Apple**: Required by App Store if offering social login
- **Google Sign-In**: Cross-platform (works on Android too)
- No passwords to manage, verify, or leak
- Users already have accounts

### Go Libraries

| Purpose | Library | Installation |
|---------|---------|--------------|
| HTTP Router | `net/http` (stdlib) | Built-in (Go 1.22+) |
| JWT | `golang-jwt/jwt/v5` | `go get github.com/golang-jwt/jwt/v5` |
| Sign in with Apple | `Timothylock/go-signin-with-apple` | `go get github.com/Timothylock/go-signin-with-apple` |
| Google Sign-In | `google.golang.org/api/idtoken` | `go get google.golang.org/api/idtoken` |
| PostgreSQL | `jackc/pgx/v5` | `go get github.com/jackc/pgx/v5` |
| Migrations | `golang-migrate/migrate` | `go get github.com/golang-migrate/migrate/v4` |

**Note:** Using pure Go stdlib (`net/http`) with Go 1.22+ for routing. No external router framework needed - stdlib now supports path parameters and method routing.

### Token Strategy

| Token | Expiration | Storage (iOS) | Purpose |
|-------|------------|---------------|---------|
| Access Token | 15 minutes | Memory only | API authentication |
| Refresh Token | 30 days | Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) | Get new access token |

**JWT Claims Structure:**
```go
type CustomClaims struct {
    jwt.RegisteredClaims
    UserID string `json:"uid"`
}
```

**Note:** Use `jwt.RegisteredClaims` for standard fields (`exp`, `iss`, `sub`). Store refresh tokens hashed (SHA-256) in database, never plaintext. Implement token rotation: issue new refresh token on each refresh to detect reuse attacks.

---

## Database Schema

```mermaid
erDiagram
    users {
        uuid id PK
        string provider "apple, google"
        string provider_id "unique per provider"
        string email
        timestamp created_at
        timestamp updated_at
    }

    reminders {
        uuid id PK
        uuid user_id FK
        string title
        timestamp scheduled_date
        boolean is_completed
        timestamp completed_date
        jsonb recurrence_rule
        timestamp recurrence_end_date
        timestamp last_scheduled_date
        timestamp created_at
        timestamp updated_at
    }

    tags {
        uuid id PK
        uuid user_id FK
        string name
        string color_hex
        timestamp created_at
        timestamp updated_at
    }

    reminder_tags {
        uuid reminder_id PK,FK
        uuid tag_id PK,FK
    }

    refresh_tokens {
        uuid id PK
        uuid user_id FK
        string token_hash
        timestamp expires_at
        timestamp created_at
        boolean revoked
    }

    users ||--o{ reminders : has
    users ||--o{ tags : has
    users ||--o{ refresh_tokens : has
    reminders }o--o{ tags : has
```

### Migration Files

**`migrations/000001_create_users.up.sql`**
```sql
-- Enable UUID extension (Neon has this enabled by default)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider VARCHAR(20) NOT NULL,
    provider_id VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(provider, provider_id)
);

CREATE INDEX idx_users_provider ON users(provider, provider_id);
```

**`migrations/000002_create_reminders.up.sql`**
```sql
CREATE TABLE reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(500) NOT NULL,
    scheduled_date TIMESTAMPTZ NOT NULL,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_date TIMESTAMPTZ,
    recurrence_rule JSONB,
    recurrence_end_date TIMESTAMPTZ,
    last_scheduled_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_reminders_user ON reminders(user_id);
CREATE INDEX idx_reminders_scheduled ON reminders(user_id, scheduled_date);
```

**`migrations/000003_create_tags.up.sql`**
```sql
CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    color_hex VARCHAR(7) NOT NULL DEFAULT '#22C55E',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, name)
);

CREATE TABLE reminder_tags (
    reminder_id UUID NOT NULL REFERENCES reminders(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (reminder_id, tag_id)
);
```

**`migrations/000004_create_refresh_tokens.up.sql`**
```sql
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id) WHERE NOT revoked;
CREATE INDEX idx_refresh_tokens_hash ON refresh_tokens(token_hash) WHERE NOT revoked;
```

---

## API Endpoints

### Authentication

| Method | Path | Description | Auth Required |
|--------|------|-------------|---------------|
| POST | `/v1/auth/apple` | Sign in with Apple ID token | No |
| POST | `/v1/auth/google` | Sign in with Google ID token | No |
| POST | `/v1/auth/refresh` | Exchange refresh token | No |
| POST | `/v1/auth/logout` | Revoke refresh token | Yes |
| DELETE | `/v1/auth/account` | Delete account and all data | Yes |

### Reminders

| Method | Path | Description | Auth Required |
|--------|------|-------------|---------------|
| GET | `/v1/reminders` | List all reminders | Yes |
| GET | `/v1/reminders/:id` | Get single reminder | Yes |
| POST | `/v1/reminders` | Create reminder | Yes |
| PUT | `/v1/reminders/:id` | Update reminder | Yes |
| DELETE | `/v1/reminders/:id` | Delete reminder | Yes |

### Tags

| Method | Path | Description | Auth Required |
|--------|------|-------------|---------------|
| GET | `/v1/tags` | List all tags | Yes |
| POST | `/v1/tags` | Create tag | Yes |
| PUT | `/v1/tags/:id` | Update tag | Yes |
| DELETE | `/v1/tags/:id` | Delete tag | Yes |

### Health

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Liveness check |
| GET | `/health/ready` | Readiness (includes DB) |

### Error Response Format

All errors return a consistent JSON envelope:

```json
{
    "error": {
        "code": "VALIDATION_ERROR",
        "message": "Title is required",
        "field": "title"
    }
}
```

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `VALIDATION_ERROR` | 400 | Invalid input data |
| `UNAUTHORIZED` | 401 | Missing or invalid token |
| `FORBIDDEN` | 403 | User doesn't own resource |
| `NOT_FOUND` | 404 | Resource doesn't exist |
| `INTERNAL_ERROR` | 500 | Server error |

---

## Go Project Structure

```
memoss-api/
├── cmd/
│   └── server/
│       └── main.go              # Entry point
├── internal/
│   ├── config/
│   │   └── config.go            # Environment config
│   ├── auth/
│   │   ├── apple.go             # Apple token verification
│   │   ├── google.go            # Google token verification
│   │   └── jwt.go               # JWT generation/validation
│   ├── handler/
│   │   ├── auth.go              # Auth endpoints (HTTP concerns only)
│   │   ├── reminder.go          # Reminder endpoints
│   │   ├── tag.go               # Tag endpoints
│   │   └── health.go            # Health checks
│   ├── service/                 # Business logic layer
│   │   ├── auth.go              # Auth business logic
│   │   ├── reminder.go          # Reminder business logic
│   │   └── tag.go               # Tag business logic
│   ├── repository/
│   │   ├── user.go              # User queries
│   │   ├── reminder.go          # Reminder queries
│   │   ├── tag.go               # Tag queries
│   │   └── token.go             # Refresh token queries
│   ├── model/
│   │   ├── user.go              # User struct
│   │   ├── reminder.go          # Reminder struct
│   │   └── tag.go               # Tag struct
│   └── server/
│       └── server.go            # HTTP server setup
├── migrations/
│   ├── 000001_create_users.up.sql
│   ├── 000001_create_users.down.sql
│   └── ...
├── go.mod                       # go 1.22 minimum
├── go.sum
├── Dockerfile                   # FROM golang:1.22-alpine
└── docker-compose.yml
```

### Layer Responsibilities

| Layer | Responsibility | Example |
|-------|----------------|---------|
| **Handler** | HTTP concerns: parse request, call service, format response | Validate JSON, return 400 for bad input |
| **Service** | Business logic: validation rules, orchestration, transformations | Check user owns reminder before update |
| **Repository** | Data access: SQL queries, database operations | `SELECT * FROM reminders WHERE user_id = $1` |

### Pure Stdlib Router Pattern (Go 1.22+)

```go
func (s *Server) routes() http.Handler {
    mux := http.NewServeMux()

    // Health (public)
    mux.HandleFunc("GET /health", s.healthHandler.Liveness)
    mux.HandleFunc("GET /health/ready", s.healthHandler.Readiness)

    // Auth (public)
    mux.HandleFunc("POST /v1/auth/apple", s.authHandler.Apple)
    mux.HandleFunc("POST /v1/auth/google", s.authHandler.Google)
    mux.HandleFunc("POST /v1/auth/refresh", s.authHandler.Refresh)

    // Auth (protected)
    mux.HandleFunc("POST /v1/auth/logout", s.withAuth(s.authHandler.Logout))
    mux.HandleFunc("DELETE /v1/auth/account", s.withAuth(s.authHandler.DeleteAccount))

    // Reminders (protected)
    mux.HandleFunc("GET /v1/reminders", s.withAuth(s.reminderHandler.List))
    mux.HandleFunc("POST /v1/reminders", s.withAuth(s.reminderHandler.Create))
    mux.HandleFunc("GET /v1/reminders/{id}", s.withAuth(s.reminderHandler.Get))
    mux.HandleFunc("PUT /v1/reminders/{id}", s.withAuth(s.reminderHandler.Update))
    mux.HandleFunc("DELETE /v1/reminders/{id}", s.withAuth(s.reminderHandler.Delete))

    // Tags (protected)
    mux.HandleFunc("GET /v1/tags", s.withAuth(s.tagHandler.List))
    mux.HandleFunc("POST /v1/tags", s.withAuth(s.tagHandler.Create))
    mux.HandleFunc("PUT /v1/tags/{id}", s.withAuth(s.tagHandler.Update))
    mux.HandleFunc("DELETE /v1/tags/{id}", s.withAuth(s.tagHandler.Delete))

    // Wrap with logging middleware
    return s.withLogging(mux)
}

// Auth middleware - validates JWT and injects user_id into context
func (s *Server) withAuth(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        token := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
        if token == "" {
            s.errorResponse(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing token")
            return
        }

        claims, err := s.jwtService.ValidateAccessToken(token)
        if err != nil {
            s.errorResponse(w, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid token")
            return
        }

        ctx := context.WithValue(r.Context(), userIDKey, claims.UserID)
        next(w, r.WithContext(ctx))
    }
}

// Get path parameter (Go 1.22+)
func getPathParam(r *http.Request, name string) string {
    return r.PathValue(name)  // e.g., r.PathValue("id")
}
```

**Note:** Go 1.22+ `net/http` supports `"METHOD /path/{param}"` syntax. Use `r.PathValue("id")` to extract path parameters. Auth middleware wraps protected handlers individually.

---

## Implementation Phases

| Phase | Title | Dependencies | Status |
|-------|-------|--------------|--------|
| 1 | Backend Foundation + Auth | None | ✅ COMPLETED |
| 2 | Reminder & Tag API | Phase 1 | ✅ COMPLETED |
| 3 | iOS Integration | Phase 2 | ✅ COMPLETED |
| 4 | Deployment | Phase 2, 3 | ✅ COMPLETED |

### Phase 1: Backend Foundation + Auth ✅ COMPLETED

**Completed:** 2026-01-23
**Repository:** https://github.com/Cerebrovinny/memoss-backend
**Commit:** 0278872

**Scope:** Project setup, database, health checks, authentication

**Deliverables:**
- [x] Go module (requires Go 1.22+) with minimal dependencies (pgx, jwt)
- [x] Neon database connection using `pgxpool.Pool` with connection pooling:
  ```go
  config.MaxConns = 10        // Neon handles pooling server-side
  config.MinConns = 2
  config.MaxConnLifetime = time.Hour
  config.MaxConnIdleTime = 30 * time.Minute
  config.HealthCheckPeriod = time.Minute
  ```
- [x] Database migrations (users, refresh_tokens)
- [x] Health check endpoints (`/health` for liveness, `/health/ready` pings DB)
- [x] Apple token verification using `Timothylock/go-signin-with-apple`:
  ```go
  claim, _ := apple.GetClaims(idToken)
  userID := (*claim)["sub"].(string)
  email := (*claim)["email"].(string)
  ```
- [x] Google token verification using `google.golang.org/api/idtoken`:
  ```go
  payload, err := idtoken.Validate(ctx, idToken, googleClientID)
  userID := payload.Claims["sub"].(string)
  email := payload.Claims["email"].(string)
  ```
- [x] JWT access/refresh token generation with `golang-jwt/jwt/v5`
- [x] Auth middleware using pure stdlib (custom `withAuth` wrapper function)
- [x] Rate limiting middleware (custom, using `sync.Map` + sliding window)
- [x] Docker setup for local development

**Files to create:**
- `cmd/server/main.go`
- `internal/config/config.go`
- `internal/server/server.go` (includes routes + middleware functions)
- `internal/server/middleware.go` (withAuth, withLogging, withRateLimit)
- `internal/handler/health.go`
- `internal/handler/auth.go`
- `internal/service/auth.go`
- `internal/auth/apple.go`
- `internal/auth/google.go`
- `internal/auth/jwt.go`
- `internal/repository/user.go`
- `internal/repository/token.go`
- `internal/model/user.go`
- `migrations/000001_create_users.up.sql`
- `migrations/000004_create_refresh_tokens.up.sql`
- `Dockerfile`
- `docker-compose.yml`

### Phase 2: Reminder & Tag API ✅ COMPLETED

**Completed:** 2026-01-23
**Commit:** edd1bab

**Scope:** Full CRUD API for reminders and tags

**Deliverables:**
- [x] Reminder CRUD endpoints
- [x] Tag CRUD endpoints
- [x] Input validation
- [x] Error handling with consistent format

**Files to create:**
- `internal/handler/reminder.go`
- `internal/handler/tag.go`
- `internal/service/reminder.go`
- `internal/service/tag.go`
- `internal/repository/reminder.go`
- `internal/repository/tag.go`
- `internal/model/reminder.go`
- `internal/model/tag.go`
- `migrations/000002_create_reminders.up.sql`
- `migrations/000003_create_tags.up.sql`

### Phase 3: iOS Integration ✅ COMPLETED

**Completed:** 2026-01-23
**Commit:** d1c9d70

**Scope:** Add sync capability to iOS app

**Deliverables:**
- [x] `APIClient` with 401 token refresh interceptor (retry once after refresh)
- [x] `AuthService` for Sign in with Apple using `AuthenticationServices` framework
- [x] `SyncService` for API communication with last-write-wins strategy
- [x] Settings UI for account management
- [x] Keychain storage using native `Security` framework (no external dependencies)

**Files created/modified:**
- `Memoss/Services/APIClient.swift` (new)
- `Memoss/Services/AuthService.swift` (new)
- `Memoss/Services/SyncService.swift` (new)
- `Memoss/Services/KeychainService.swift` (new) - native Security framework wrapper
- `Memoss/Features/Settings/SettingsView.swift` (new)
- `Memoss/Models/Reminder.swift` (modified - added remoteID, createdAt, updatedAt, notes)
- `Memoss/Models/Tag.swift` (modified - added remoteID, updatedAt)
- `Memoss/Features/Dashboard/DashboardView.swift` (modified - added settings button, auto-sync)
- `Memoss/Features/CreateReminder/CreateReminderView.swift` (modified - push on create)
- `Memoss/Features/EditReminder/EditReminderView.swift` (modified - push on update/delete)

### Phase 4: Deployment ✅ COMPLETED

**Completed:** 2026-01-23
**URL:** https://memoss-backend.fly.dev
**Commit:** 67e55ec

**Scope:** Production deployment to Fly.io

**Deliverables:**
- [x] Fly.io deployment configuration (`fly.toml`)
- [x] Environment variables setup (DATABASE_URL, JWT_SECRET, Apple/Google credentials)
- [x] Production Neon database with migrations applied
- [x] Health checks configured (`/health`, `/health/ready`)

**Infrastructure:**
- Region: GRU (São Paulo)
- 2 machines for high availability
- Auto-stop when idle (cost optimization)
- TLS/HTTPS enabled

---

## iOS App Changes

### New Files

**`Memoss/Services/AuthService.swift`**
```swift
import AuthenticationServices
import GoogleSignIn

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isAuthenticated = false
    @Published var user: User?

    func signInWithApple() async throws { /* ... */ }
    func signInWithGoogle() async throws { /* ... */ }
    func signOut() async { /* ... */ }
    func deleteAccount() async throws { /* ... */ }
}
```

**`Memoss/Services/SyncService.swift`**
```swift
@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?

    func syncReminders() async throws { /* ... */ }
    func uploadReminder(_ reminder: Reminder) async throws { /* ... */ }
    func downloadReminders() async throws -> [Reminder] { /* ... */ }
}
```

**`Memoss/Services/APIClient.swift`**
```swift
final class APIClient {
    private let baseURL: URL
    private let keychainService: KeychainService
    private var accessToken: String?  // In-memory only (15 min TTL)
    private var isRefreshing = false

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        var request = makeRequest(endpoint)

        // Add access token if available
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse

        // Handle 401 - token expired, attempt refresh once
        if httpResponse?.statusCode == 401, !isRefreshing {
            isRefreshing = true
            defer { isRefreshing = false }

            guard let refreshToken = keychainService.getRefreshToken() else {
                throw APIError.unauthorized
            }

            let tokens = try await refreshTokens(refreshToken)
            accessToken = tokens.accessToken
            keychainService.setRefreshToken(tokens.refreshToken)

            return try await self.request(endpoint)  // Retry with new token
        }

        // Handle other errors
        if let statusCode = httpResponse?.statusCode, statusCode >= 400 {
            let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.serverError(code: apiError?.error.code ?? "UNKNOWN", message: apiError?.error.message ?? "")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

**Note:** The `isRefreshing` flag prevents infinite refresh loops. Access token stays in memory; refresh token in Keychain with `accessibleAfterFirstUnlockThisDeviceOnly` for security.

### Settings UI Flow

```
Settings
├── Account
│   ├── [Not signed in]
│   │   ├── "Sign in with Apple" button
│   │   └── "Sign in with Google" button
│   └── [Signed in]
│       ├── Email/name display
│       ├── "Sign Out" button
│       └── "Delete Account" button (destructive)
├── Sync
│   ├── "Enable Cloud Sync" toggle (requires account)
│   ├── "Last synced: [date]"
│   └── "Sync Now" button
└── About
    └── Version, etc.
```

### User Flow: Local vs Cloud Mode

```mermaid
flowchart TD
    A[App Launch] --> B{Has Account?}
    B -->|No| C[Local Mode]
    B -->|Yes| D{Sync Enabled?}
    D -->|No| C
    D -->|Yes| E[Cloud Mode]

    C --> F[SwiftData Local Only]
    E --> G[SwiftData + API Sync]

    G --> H[On Change: Queue for sync]
    H --> I[Background sync to API]
    I --> J[Merge remote changes]
```

---

## Acceptance Criteria

### AC1: Local Mode (No Account)
**Given** user has not created an account
**When** they use the app
**Then** all data stays on device only, no network calls made

### AC2: Sign In with Apple
**Given** user taps "Sign in with Apple"
**When** authentication completes
**Then** user receives JWT tokens and can sync

### AC3: Sign In with Google
**Given** user taps "Sign in with Google"
**When** authentication completes
**Then** user receives JWT tokens and can sync

### AC4: Cross-Device Sync
**Given** user is signed in on Device A and Device B
**When** they create a reminder on Device A
**Then** it appears on Device B after sync

### AC5: Offline Support
**Given** user is offline
**When** they create/edit reminders
**Then** changes sync when connectivity returns

### AC6: Account Deletion
**Given** user requests account deletion
**When** confirmed
**Then** all server data is permanently deleted, local data optionally kept

---

## Security Considerations

- [ ] All API endpoints use HTTPS (Fly.io provides TLS termination)
- [ ] Refresh tokens hashed before storage using SHA-256:
  ```go
  hash := sha256.Sum256([]byte(refreshToken))
  tokenHash := hex.EncodeToString(hash[:])
  ```
- [ ] Token rotation: issue new refresh token on each `/v1/auth/refresh` call to detect reuse attacks
- [ ] Rate limiting on auth endpoints (10/min per IP) using custom sliding window middleware:
  ```go
  // Simple rate limiter using sync.Map
  type RateLimiter struct {
      requests sync.Map  // key: IP, value: []time.Time
      limit    int
      window   time.Duration
  }

  func (rl *RateLimiter) Allow(ip string) bool {
      // Sliding window: count requests in last `window` duration
  }
  ```
- [ ] Input validation on all endpoints
- [ ] SQL injection prevention (parameterized queries via pgx - never string concatenation)
- [ ] JWT secret stored in environment variable, minimum 256 bits
- [ ] CORS disabled (mobile-only API, no browser access needed)

---

## Environment Variables

```bash
# Database
DATABASE_URL=postgres://user:pass@ep-xxx-pooler.neon.tech/memoss?sslmode=require
DATABASE_URL_DIRECT=postgres://user:pass@ep-xxx.neon.tech/memoss?sslmode=require

# JWT
JWT_SECRET=your-256-bit-secret
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=720h

# Apple Sign In
APPLE_TEAM_ID=XXXXXXXXXX
APPLE_KEY_ID=XXXXXXXXXX
APPLE_CLIENT_ID=com.stack4nerds.memoss
APPLE_PRIVATE_KEY_PATH=/path/to/AuthKey.p8

# Google Sign In
GOOGLE_CLIENT_ID=xxxxx.apps.googleusercontent.com

# Server
PORT=8080
ENVIRONMENT=production
```

---

## References

### External Documentation
- [golang-jwt/jwt v5](https://github.com/golang-jwt/jwt)
- [Sign in with Apple Go Library](https://github.com/Timothylock/go-signin-with-apple)
- [Google ID Token Verification](https://pkg.go.dev/google.golang.org/api/idtoken)
- [Neon Go Guide](https://neon.com/docs/guides/go)
- [pgx PostgreSQL Driver](https://github.com/jackc/pgx)
- [golang-migrate](https://github.com/golang-migrate/migrate)
- [chi Router](https://github.com/go-chi/chi)

### Internal References
- `Memoss/Models/Reminder.swift:11-67` - iOS Reminder model to match
- `Memoss/Models/Tag.swift:12-32` - iOS Tag model to match
- `Memoss/Models/RecurrenceRule.swift:10-15` - Recurrence enum (store as JSONB)
- `plans/feat-cross-device-sync.md` - Previous CloudKit plan (alternative approach)

### Apple/Google Setup Guides
- [Apple: Implementing Sign in with Apple](https://developer.apple.com/documentation/AuthenticationServices/implementing-user-authentication-with-sign-in-with-apple)
- [Google: iOS Backend Auth](https://developers.google.com/identity/sign-in/ios/backend-auth)
