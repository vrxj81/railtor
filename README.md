# Railtor – Sport Supplement Webshop (MVP)

This repository is a monorepo managed with Nx that hosts a Rails 8 API-only backend and an Angular 20 frontend for a sport supplement webshop.
The MVP scope starts with authentication, authorization, and role management (admin, editor, service).

⸻

## 📦 Workspace Overview

- Monorepo Tooling: Nx
- Backend: Rails 8 (API-only)
    - Devise for authentication (JWT)
    - Pundit for authorization
    - PostgreSQL for persistence
    - RSpec for testing
- **Frontend**: Angular 20  
    - Zoneless change detection (`provideZoneChangeDetection`)  
    - Standalone components with ApplicationConfig  
    - Angular Signals for state and derived data  
    - NgRx **SignalStore** for feature state management  
    - **CASL for role-based UI** (`@casl/ability`, `@casl/angular`) to mirror API permissions on the client
- Standards:
    - Commit messages, generators, formatting, and linting follow Nx defaults
    - Prettier (TS) + ESLint rules for frontend
    - RuboCop for backend

## 🗂️ Project Structure

```
apps/
  web/        # Angular frontend
  api/        # Rails API-only backend
packages/
  <domain>/feature-*   # UI flows
  <domain>/data-access # HTTP clients + SignalStores
  <domain>/ui-*        # Presentational components
  shared/              # Cross-cutting utilities (styles, models, utils)
```

- apps/: deployable artifacts (frontend and backend)
- packages/: shared libraries, organized by domain and type
- Nx enforced boundaries ensure feature/data-access/ui separation

⸻

## 🔑 MVP Scope

### Roles

- Admin: full access, including user and system management
- Editor: manage products, variants, categories, coupons, and inventory
- Service: view and update order status, manage notes, customer support

### Features

1. Authentication & Authorization
    - Sign up, sign in, sign out
    - JWT access tokens (15m) + rotating refresh tokens (14d)
    - Password reset flow (forgot + reset)
    - **Server-side authorization** with Pundit  
    - **Client-side role-based UI** with CASL (guards, structural directives)

2. Security
    - Rate limiting with rack-attack
    - Brute force lockout (5 failed attempts → temporary lock)
    - Audit log for sign-in, reset, and role-related actions

3. Frontend UX
    - Auth screens (sign in/up/forgot/reset)  
    - **CASL-powered directives** to hide/disable UI by ability  
    - Tokens via SignalStore + sessionStorage  
    - Interceptors for auth headers and refresh logic

4. Backend
    - User model with roles (enum)
    - Devise for auth, JWT tokens for API
    - Pundit policies for resource access
    - Request specs for auth flows

⸻

## ⚙️ Setup & Installation

### Requirements

- Node.js 20+
- yarn
- Ruby 3.4+
- PostgreSQL 15+ (or Docker)
- Nx CLI (npm i -g nx)

## Install

```bash
# Clone repo
git clone <repo-url>
cd railtor

# Install frontend deps
yarn install

# Install backend deps
cd apps/api
bundle install

# Spin up PostgreSQL for local dev (optional, requires Docker)
cd ../..
docker compose up -d postgres

# Setup DB (runs against dockerized Postgres if running)
cd apps/api
cp .env.development.sample .env.development.local # optional, then tweak creds
bin/rails db:setup
```

⸻

## ▶️ Development

### Start frontend (Angular)

```bash
nx serve web
# → http://localhost:4200
```

### Start backend (Rails API)

```bash
nx serve api
# → http://localhost:3000
```

### Start both together

```bash
nx run-many --target=serve --projects=web,api
```

## 🔄 API Contract (Auth v1)

| Endpoint                | Method | Description |
|------------------------|--------|-------------|
| `/auth/sign_up`         | POST   | Register new user |
| `/auth/sign_in`         | POST   | Login (returns access + refresh) |
| `/auth/refresh`         | POST   | Refresh access token |
| `/auth/sign_out`        | POST   | Invalidate refresh token |
| `/auth/password/forgot` | POST   | Request password reset link |
| `/auth/password/reset`  | POST   | Reset password with token |


JWT Claims: `sub`, `role`, `iat`, `exp`, `jti`


## 🛡️ Quality & Security

- Linting
- Prettier + ESLint for frontend
- RuboCop for backend
- Testing
- Angular: Vitest/Jest unit tests + Playwright component/e2e tests
- Rails: RSpec request and model specs
- CI/CD
- Use nx affected commands to run only impacted tests, lint, and builds
- Secrets
- Keep secrets in .env (ignored from git)
- Configure JWT keys, DB credentials, and mailer settings via ENV

⸻

## 📚 Documentation

- Copilot Instructions: see .github/copilot-instructions.md
- Decision Records: docs/decision-records/ for architectural decisions
- API Docs: apps/api/docs (OpenAPI/Swagger planned)

⸻

## ✅ Roadmap

### S1 (MVP Auth & RBAC)

- User model & JWT auth
- Pundit policies
- Angular auth flow with SignalStore

### S2 (Catalog & Checkout)

- Products, categories, variants
- Shopping cart & Stripe checkout
- Orders & fulfillment

### S3 (Operations & Service)

- Coupons & discounts
- Order management (admin/editor/service)
- Customer service dashboard
