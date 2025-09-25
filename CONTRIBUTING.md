# Contributing to Railtor

This document defines the **required workflow, conventions, and quality gates** for the Railtor monorepo.  
**All contributors must follow these rules.**

## 🔀 Branching Model
- `main`: protected, always deployable, PRs only
- Feature: `feature/<short-description>`
- Fix: `fix/<short-description>`
- Chore: `chore/<short-description>`
- Release: `release/<version>`

## 📝 Commit Messages (Conventional Commits)
Format:

(): 

Types: `feat|fix|chore|docs|test|refactor|style`  
Scopes: `web`, `api`, `auth`, `catalog`, etc.

## ⚒️ Code Generation & Structure
**Always** use Nx/Rails generators; never handcraft structure in `apps/` or `packages/`.

### Angular
- Standalone components only; zoneless change detection
- **Signals** for state (no `BehaviorSubject`)
- Libraries:
    - `feature-*` (smart/flows)
    - `data-access` (HTTP, SignalStores, DTO mapping)
    - `ui-*` (presentational)
    - `shared/` (styles, models, utils)
- Sass, component-scoped styles
- **NgRx SignalStore** required for feature state

### Rails
- Generators for models/controllers/migrations
- Devise (JWT) for auth
- Pundit for authorization (`authorize`, `policy_scope` in controllers)
- RSpec: request/model/policy specs
- Serializers: Blueprinter

## 🧪 Testing Requirements
**Frontend**
- Unit tests (Vitest/Jest) for components/services
- Playwright component/e2e for critical flows (auth, catalog, checkout)
- **80%+ coverage required**

**Backend**
- RSpec request specs for every endpoint
- Model specs for validations/methods
- Policy specs for each Pundit policy
- FactoryBot only (no fixtures)

## 🔍 Linting & Formatting
- Frontend: ESLint + Prettier → `nx lint web`
- Backend: RuboCop → `bundle exec rubocop`
- Formatting must be clean before PR review

## 🚦 Pull Request Process
1. Branch from `main`
2. Implement with tests
3. Run locally:
```bash
nx affected:test –all
nx affected:lint –all
nx affected:build –all
bundle exec rspec
```
4. Open PR (Conventional Commit title). Describe **What/Why/How tested**. Link issues.
5. CI must pass
6. ≥1 approving review
7. Squash merge

## 🔑 Secrets & Environment
- No secrets in repo
- Use `.env` (ignored)
- Backend env: `JWT_SECRET`, `REFRESH_SECRET`, `DATABASE_URL`, `MAIL_*`
- Frontend env: `API_BASE_URL`, `STRIPE_PUBLIC_KEY` (later)

## 📚 Documentation
- Update `docs/decision-records/` for architecture decisions
- Update `apps/api/docs` (OpenAPI) when API changes
- Keep `README.md` current

---

## 🔐 Client-side Role-based UI **(CASL – Mandatory)**

We enforce **CASL** for all client-side permissions to keep UI consistent with server policies.

### Packages
- `@casl/ability`
- `@casl/angular` (see https://casl.js.org/v6/en/package/casl-angular)

Install in `apps/web`:
```bash
pnpm add @casl/ability @casl/angular
```
### Ability Model (single source of truth)
- Define abilities from the authenticated user’s role and any server-provided permission hints.
- Location: packages/shared/ability
- ability.factory.ts: builds AppAbility from User (role)
- ability.types.ts: action/subject types (e.g., read, create, update, delete; subjects like Product, Order, Coupon, Settings)

### Rules mapping (minimum):
- admin: can manage all
- editor: can manage Product|Variant|Category|Coupon; can read Order
- service: can read Order; can update Order where { field: 'status' }; can create OrderNote

> Any UI that conditions visibility or enabled state must use Ability checks.

## App Wiring
- Provide ability at app root (ApplicationConfig) and update it on login/refresh:
    - When AuthStore receives a user, call ability.update(defineRulesFor(user))
    - On logout, reset to guest abilities (read public pages only)

## Usage Rules
- Structural directives (preferred):
    - *caslCan="'update'; 'Product'" to render/hide blocks
- Attribute binding for disabled state when hiding is undesirable:
    - [disabled]="!$ability.can('update', 'Order')"
- Route guards:
    - Implement a canMatch guard that checks $ability.can(action, subject) for admin routes
- No ad-hoc role checks:
    - if (user.role === 'admin') is forbidden in components; use CASL

## Example Snippets

### Ability factory
```ts
// packages/shared/ability/ability.factory.ts
import { AbilityBuilder, createMongoAbility, MongoAbility } from '@casl/ability';
import type { AppActions, AppSubjects, User } from './ability.types';

export type AppAbility = MongoAbility<[AppActions, AppSubjects]>;

export function defineRulesFor(user: User) {
  const { can, cannot, build } = new AbilityBuilder<AppAbility>(createMongoAbility);

  switch (user?.role) {
    case 'admin':
      can('manage', 'all');
      break;
    case 'editor':
      can('manage', 'Product');
      can('manage', 'Variant');
      can('manage', 'Category');
      can('manage', 'Coupon');
      can('read', 'Order');
      break;
    case 'service':
      can('read', 'Order');
      can('update', 'Order', ['status']); // restrict to status field in UI
      can('create', 'OrderNote');
      cannot('manage', 'Settings');
      break;
    default:
      // guest
      can('read', 'Catalog');
  }

  return build({
    detectSubjectType: (obj) => obj!.type ?? obj,
  });
}
```
### Directive usage
```html
<!-- Hide entire actions toolbar if user can’t update products -->
<div *caslCan="'update'; 'Product'">
  <button (click)="save()">Save</button>
</div>

<!-- Disable refund button if not allowed -->
<button [disabled]="!$ability.can('create', 'Refund')">Refund</button>
```
### Guard
```ts
export const adminRouteGuard: CanMatchFn = () => {
  const ability = inject(Ability); // from @casl/ability
  return ability.can('manage', 'Settings');
};
```
## Sync with Server (Pundit)
- Server remains the source of truth. Always enforce authorization on API.
- For sensitive actions, re-validate on server even if UI allowed the button.
- If Pundit denies an action the UI allowed, show a toast and refresh ability if needed.

## Testing (Required)
- Unit tests for the ability factory:
    - Assert expected permissions per role (can/cannot)
- Component tests:
    - Verify *caslCan hides/shows content as expected
    - Verify [disabled] toggles based on ability
- Route guard tests:
    - Ensure restricted routes are blocked for non-permitted roles


## ✅ Definition of Done (reaffirmed)

A contribution is done only if:
- All tests pass (web + api), coverage ≥ 80%
- Lint/format clean
- CASL used for all role-based UI conditionals
- Server-side authorization (Pundit) enforced on all protected endpoints
- Docs updated (README/ADR/API)
- PR reviewed and approved
