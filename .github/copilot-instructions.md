# Copilot Instructions for the Railtor Workspace

## Overview
- Monorepo managed with Nx.
- Backend: Rails 8 API-only application with Devise for authentication and Pundit for authorization.
- Frontend: Angular 20 application using zoneless change detection, Angular signals, and NgRx SignalStore per Angular Architects best practices.
- Commit messages, generators, formatting, and linting should align with Nx defaults.

## Workspace & Project Structure
- Keep `apps/` for deployable artifacts (`apps/web` for Angular, `apps/api` for Rails). Place shared logic in `packages/` as feature, data-access, or utility libraries.
- Use Nx generators (`nx g @nx/angular:app`, `nx g @nx/workspace:lib`, etc.) instead of manual scaffolding to stay consistent.
- Enable incremental builds and caching by correctly specifying project dependencies in `project.json` or `project.json`-equivalent files per Nx standards.
- Enforce strict TypeScript settings in `tsconfig.base.json`; avoid `any` unless absolutely necessary and document exceptions.

## Angular 20 Frontend Guidelines
- Configure the root Angular app with zoneless change detection (`provideZoneChangeDetection({ eventCoalescing: true })`). Use `ApplicationConfig` with standalone components; avoid NgModules.
- Prefer Angular signals for component state and derived data. Use `toSignal`, `signal`, `computed`, and `effect` thoughtfully; keep side effects in `effect` blocks only.
- Structure libraries by domain:
  - `packages/<domain>/feature-*` for UI flows.
  - `packages/<domain>/data-access` for HTTP clients, SignalStore definitions, and DTO mapping.
  - `packages/<domain>/ui-*` for pure presentational components.
  - `packages/shared` for cross-cutting utilities.
- Employ Nx enforced boundaries via `tslint`/`eslint` rules; keep UI libraries dependency-free from data-access.
- Fiber-ready hydration: ensure SSR compatibility by using Angular 20 hydration APIs when adding server rendering.
- Styling: Use Sass with the Angular CLI default; scope styles to components, and prefer design tokens stored in a shared style library.

## NgRx SignalStore Usage
- Store feature state in SignalStores housed within `data-access` libraries.
- Follow Angular Architects best practices:
  - Use `signalStore` factory with `withState`, `withComputed`, `withMethods`, `withHooks`, and `withEntities` when relevant.
  - Keep API calls inside `withMethods` and return promises or observables converted to signals where appropriate.
  - Co-locate selectors with the store. Expose read-only signals to components; do not expose writable state directly.
  - Provide optimistic update patterns with rollback logic if API operations fail.
- Testing: write SignalStore tests using `fakeAsync`/`flush` with the zoneless testing module. Validate state transitions and computed values.

## Rails 8 API Guidelines
- Generate the backend with `rails new apps/api --api --database=postgresql`. Keep Rails project isolated within `apps/api`.
- Use Devise for user authentication. Configure JWT or session-based auth depending on frontend needs; keep tokens short-lived and refresh securely.
- Implement role-based access control with Pundit. Place policies under `app/policies`, and ensure controllers use `authorize`/`policy_scope`.
- Enforce strong parameters and JSON responses. Prefer serializers (e.g., ActiveModelSerializers or Blueprinter) for consistent payloads.
- Add background job support with ActiveJob and a reliable adapter (e.g., Sidekiq). Store configuration under `config/` and ensure jobs enqueue through service objects.
- Testing: use RSpec (preferred) or Minitest with request specs covering authentication, authorization, and edge cases.
- Secure defaults: enable SSL in production, force secure cookies, and configure CORS via `rack-cors` to match the Angular origin.

## Cross-App Integration
- Define shared API contracts using OpenAPI/Swagger in `apps/api/docs` and generate TypeScript clients via Nx workspace generators when possible.
- Use environment-specific configuration files in Angular (`environment.ts`) and Rails (`config/environments/*.rb`) to manage API URLs and feature flags.
- For local dev, run Rails on port 3000 and Angular on port 4200; use Nx tasks to orchestrate (`nx run-many --target=serve --projects=api,web`).
- Handle authentication headers in Angular interceptors. Maintain refresh-token logic inside a dedicated SignalStore service.

## Tooling & Quality Gates
- Enforce formatting with Prettier (TS) and Rubocop (Ruby); integrate with Nx lint targets.
- Write unit tests (Karma/Vitest) plus component tests (Playwright) for Angular. Maintain Jest/Vitest support as configured in Nx.
- Use Nx affected commands in CI to run only impacted tests/lints/builds.
- Document new commands or architecture decisions in `README.md` and, when major, record them in `docs/decision-records/`.

## Security & Compliance
- Keep secrets out of the repo. Use `.env` files (ignored) or Nx environment handling.
- Regularly update dependencies (Node, Angular, Rails gems). Run `yarn npm-check-updates` and `bundle update` selectively, verifying breaking changes.
- Implement automated security scans (e.g., `npm audit`, `bundle audit`) and track findings.

Adhering to this playbook ensures Copilot and contributors generate code consistent with the Railtor architecture and standards.