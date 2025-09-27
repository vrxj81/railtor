# Railtor API

This API is an authentication-first Rails 8 service that issues short-lived JWT
access tokens backed by rotating refresh tokens. The endpoints below are
available under the `/auth` namespace and respond with JSON.

## Authentication Overview

- **Access tokens** expire after 5 minutes and include the claims
  `{ sub, role, iat, exp, jti }`.
- **Refresh tokens** expire after 14 days, are rotated on every use, and are
  persisted server-side hashed via SHA-256.
- **Authentication endpoints** are rate-limited to 10 requests per minute per
  IP and accounts automatically unlock 15 minutes after hitting the lockout
  threshold.
- **CORS** is only enabled in development to allow the Angular dev server at
  `http://localhost:4200`; production serves the built frontend from
  `apps/api/public`.

## Seed data

`rails db:seed` provisions default platform accounts using environment-provided
passwords. Set the following variables before running the task:

- `ADMIN_PASSWORD` (required) — optional `ADMIN_EMAIL`, defaults to
  `admin@railtor.local`
- `EDITOR_PASSWORD` (required) — optional `EDITOR_EMAIL`, defaults to
  `editor@railtor.local`
- `SERVICE_PASSWORD` (required) — optional `SERVICE_EMAIL`, defaults to
  `service@railtor.local`

The seed script is idempotent; repeated runs will upsert the three users and
reset lockout counters so the accounts remain accessible.

### CI/CD example

For GitHub Actions you can inject the required variables via workflow secrets:

```yaml
env:
	ADMIN_EMAIL: admin@railtor.local
	ADMIN_PASSWORD: ${{ secrets.API_ADMIN_PASSWORD }}
	EDITOR_EMAIL: editor@railtor.local
	EDITOR_PASSWORD: ${{ secrets.API_EDITOR_PASSWORD }}
	SERVICE_EMAIL: service@railtor.local
	SERVICE_PASSWORD: ${{ secrets.API_SERVICE_PASSWORD }}

steps:
	- name: Prepare database
		run: |
			bundle exec rails db:prepare
			bundle exec rails db:seed
```

For containerised deployments, mount the variables as environment entries in
Kubernetes or Docker Compose and invoke `bundle exec rails db:seed` during the
release pipeline.

- All responses use snake_case error codes inside an `error` envelope when
  requests fail (see individual endpoints for details).

## Endpoints

### GET `/settings`

Returns application-level operational settings. Requires an authenticated admin
access token.

```jsonc
// Headers
// Authorization: Bearer <access jwt>

// Response 200
{
	"application": {
		"name": "Railtor",
		"version": "0.0.1"
	},
	"features": {
		"authentication": true,
		"password_reset": true
	}
}

// Response 401 (no/invalid token)
{
	"error": {
		"code": "unauthenticated",
		"message": "Authorization header is missing or invalid."
	}
}

// Response 403 (non-admin roles)
{
	"error": {
		"code": "not_authorized",
		"message": "You are not authorized to perform this action."
	}
}
```

### POST `/auth/sign_up`

Registers a new user as a `customer`.

```jsonc
// Request body
{
	"email": "user@example.com",
	"password": "Supersafe01!"
}

// Response 201
{
	"id": 42,
	"email": "user@example.com",
	"role": "customer"
}

// Response 422 (validation error)
{
	"errors": [
		{ "field": "email", "message": "has already been taken" }
	]
}
```

### POST `/auth/sign_in`

Authenticates a confirmed user and returns both access and refresh tokens.

```jsonc
// Request body
{
	"email": "user@example.com",
	"password": "Supersafe01!"
}

// Response 200
{
	"accessToken": "<jwt>",
	"refreshToken": "<jwt>",
	"user": {
		"id": 42,
		"email": "user@example.com",
		"role": "customer"
	}
}

// Response 401 (invalid credentials)
{
	"error": {
		"code": "invalid_credentials",
		"message": "Invalid email or password."
	}
}

// Response 423 (account locked after 5 failed attempts)
{
	"error": {
		"code": "account_locked",
		"message": "Account is locked due to too many failed attempts."
	}
}
```

### POST `/auth/refresh`

Rotates a refresh token and issues a new token pair. The submitted refresh token
is invalidated on success.

```jsonc
// Request body
{
	"refreshToken": "<jwt>"
}

// Response 200
{
	"accessToken": "<new jwt>",
	"refreshToken": "<new jwt>",
	"user": {
		"id": 42,
		"email": "user@example.com",
		"role": "customer"
	}
}

// Response 401 (token invalid/expired/replayed)
{
	"error": {
		"code": "invalid_refresh_token",
		"message": "Refresh token is invalid."
	}
}

// Response 422 (token missing)
{
	"error": {
		"code": "invalid_refresh_token",
		"message": "refreshToken is required"
	}
}
```

### POST `/auth/sign_out`

Revokes the provided refresh token, preventing future use.

```jsonc
// Request body
{
	"refreshToken": "<jwt>"
}

// Response 200
{ "success": true }

// Response 401 (token already rotated/invalid)
{
	"error": {
		"code": "invalid_refresh_token",
		"message": "Refresh token is invalid."
	}
}
```

### POST `/auth/password/forgot`

Initiates the password reset flow. Always responds with success to avoid leaking
user existence.

```jsonc
// Request body
{
	"email": "user@example.com"
}

// Response 200 (sent regardless of account existence)
{ "success": true }
```

### POST `/auth/password/reset`

Completes a password reset using the token delivered via email.

```jsonc
// Request body
{
	"token": "<reset token>",
	"password": "Supersafe01!"
}

// Response 200
{ "success": true }

// Response 400 (invalid or expired token)
{
	"error": {
		"code": "invalid_or_expired_token",
		"message": "Reset token is invalid or has expired."
	}
}

// Response 422 (password fails validation)
{
	"errors": [
		{ "field": "password", "message": "is too short (minimum is 10 characters)" }
	]
}
```

## Running the Specs

Use the Nx target to run linting and tests for the API:

```bash
yarn nx affected -t lint test --base=origin/main --head=HEAD
```

Or run the Rails request specs directly:

```bash
cd apps/api
bundle exec rspec spec/requests/authentication_spec.rb
```
