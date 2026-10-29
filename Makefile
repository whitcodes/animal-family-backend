# Configuration comes from Doppler by default: targets that run Go code or psql
# are wrapped in `doppler run --`, and the Doppler config (dev/stg/prd) supplies
# ENVIRONMENT and everything else. ENVIRONMENT has no default
# (config/env.go fails fast if it's missing or unrecognized).
#
# To use a .env file instead, pass ENV_FILE:
#   make run ENV_FILE=.env
# The binary loads it itself via godotenv (which handles quoted values
# correctly), and ENVIRONMENT defaults to "development" unless it's already
# exported. Targets that run psql source the file in the shell instead, since
# Make's own `include` does NOT strip quotes (KEY="value" would literally
# become "value" with the quotes as part of the string).
#
# `test` needs neither: it uses no database and sets ENVIRONMENT=test itself.

ifdef ENV_FILE
WITH_ENV = ENV_FILE=$(ENV_FILE) ENVIRONMENT=$${ENVIRONMENT:-development}
else
WITH_ENV = doppler run --
endif

# Local Postgres for development, in a container so it can't touch RDS. Only
# the database is containerized; the Go app runs directly on the host. Match
# these in your Doppler dev config (or .env): DB_HOST=localhost DB_PORT=5432
# DB_USER=postgres DB_PASSWORD=$(LOCAL_DB_PASSWORD) DB_NAME=brindl_dev
# DB_SSL_MODE=disable
LOCAL_DB_CONTAINER = animal-family-db
LOCAL_DB_PASSWORD = postgres

build:
	@go build -o bin/animal-family-backend cmd/main.go

test:
	@ENVIRONMENT=test go test -v ./...

run: build
	@$(WITH_ENV) ./bin/animal-family-backend

migration:
	@migrate create -ext sql -dir cmd/migrate/migrations $(filter-out $@,$(MAKECMDGOALS))

.PHONY: build test run migration seed migrate-up migrate-down vapid-keys spec spec-check install-hooks db-up db-down db-psql

PSQL = PGPASSWORD=$$DB_PASSWORD psql -h $$DB_HOST -p $$DB_PORT -U $$DB_USER -d $$DB_NAME

ifdef ENV_FILE
RUN_PSQL = set -a; . ./$(ENV_FILE); set +a; $(1)
else
RUN_PSQL = doppler run -- sh -c '$(1)'
endif

seed:
	@$(call RUN_PSQL,$(PSQL) -f cmd/migrate/seed/seed.sql)

migrate-up:
	@$(WITH_ENV) go run cmd/migrate/main.go up

# Runs against whatever database the active config points at. Check your
# Doppler config first: `doppler run -- printenv DB_HOST`.
migrate-down:
	@$(WITH_ENV) go run cmd/migrate/main.go down

db-up:
	@docker start $(LOCAL_DB_CONTAINER) >/dev/null 2>&1 || docker run -d --name $(LOCAL_DB_CONTAINER) \
		-e POSTGRES_PASSWORD=$(LOCAL_DB_PASSWORD) -e POSTGRES_DB=brindl_dev \
		-p 127.0.0.1:5432:5432 -v animal-family-pgdata:/var/lib/postgresql/data postgres:16 >/dev/null
	@echo "Local Postgres running as '$(LOCAL_DB_CONTAINER)' on 127.0.0.1:5432"

db-down:
	@docker stop $(LOCAL_DB_CONTAINER)

db-psql:
	@docker exec -it $(LOCAL_DB_CONTAINER) psql -U postgres -d brindl_dev

vapid-keys:
	@go run cmd/vapidgen/main.go

# Regenerates the v2 API contract. swag scans the @-annotations on v2 handlers
# to emit Swagger 2.0; specgen strips Go package prefixes from schema names and
# converts to the OpenAPI 3.0 that the frontend's generator consumes. Commit
# docs/openapi.json — it is the contract the generated client is built from.
spec:
	@go tool swag init -g cmd/main.go -o docs --ot json --parseInternal --quiet
	@go run ./cmd/specgen

# Fails if docs/openapi.json is out of date with the annotations in the code.
# Uses status --porcelain rather than diff so an uncommitted (untracked) spec
# fails too; `git diff` only reports on tracked files and would pass silently.
spec-check: spec
	@if [ -n "$$(git status --porcelain docs/openapi.json)" ]; then \
		echo "docs/openapi.json is not committed or is out of date."; \
		echo "Run 'make spec' and commit the result."; \
		git --no-pager diff -- docs/openapi.json | head -40; \
		exit 1; \
	fi

install-hooks:
	@git config core.hooksPath .githooks
	@chmod +x .githooks/*
	@echo "Git hooks installed (gofmt + go vet will run before each commit)"
