# Railtor API

This API is an authentication-first Rails 8 service that issues short-lived JWT
access tokens backed by rotating refresh tokens. The endpoints below are
available under the `/auth` namespace and respond with JSON.

## Authentication Overview

- **Access tokens** expire after 5 minutes and include the claims
  `{ sub, role, iat, exp, jti }`.
- **Refresh tokens** expire after 14 days, are rotated on every use, and are
  persisted server-side hashed via SHA-256.
- All responses use snake_case error codes inside an `error` envelope when
  requests fail (see individual endpoints for details).

## Endpoints

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
