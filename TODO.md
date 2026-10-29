# To-Do

## In Progress

- [ ] Task endpoints (routes and store)

## Backend

- [ ] Add `CreateAnimalAndEnclosure` for simultaneous creation (`CreateEnclosureWithAnimals` already exists)
- [ ] Add `UpdateUser` function and route
- [ ] Add `UpdateAnimalSubject` and `UpdateEnclosureSubject` functions and routes
- [ ] Add ownership transfer request flow (user must accept before ownership changes)
  - `handleUserUpdateAnimalOwner`
  - `handleUserUpdateEnclosureOwner`
  - `handleUserUpdateTaskOwner`
- [ ] Add duplicate check when changing ownership
- [ ] Fix transaction rollbacks in Task service (`CreateTask`, `DeleteTaskById`)
- [ ] Modularize repeated ownership checks across route handlers
- [ ] Use goroutines/WaitGroups for concurrent batch operations (e.g., `DeleteUserById` loops)
  - Will require more modular store functions

## Infra / DevOps

- [x] Verify `OPENAI_API_KEY` has been added to the live ECS task definition (`brindl-backend`) — confirmed present in revision 7 (2026-07-31)
- [ ] When setting up Terraform/IaC for ECS (see CLAUDE.md "Deployment"): move secrets out of the task definition's plaintext `environment` block into AWS Secrets Manager/SSM, referenced via the task def's `secrets` field. Terraform should declare the full set of secret references as code so a re-render can't silently drop one, and so secrets aren't readable in plaintext via `describe-task-definition`

- [ ] Rename everything to "Brindl" (repo names, Go module path, DB names, ECS/ECR resource names already use `brindl-*`, user-facing strings, `VAPID_SUBJECT` domain)
  - [x] Dev DB: local Postgres is now `brindl_dev` (Makefile `db-up`, README; Doppler `dev` `DB_NAME` to match)
  - [ ] Prod DB: `animalfamily` -> `brindl_prd` on RDS `brindl-db`. Take a snapshot first, scale the ECS service to 0 (the rename needs zero connections), connect to the `postgres` database and run `ALTER DATABASE animalfamily RENAME TO brindl_prd;`, then set `DB_NAME` in the `prd` config / task definition and scale back up. Expect a few minutes of downtime. `schema_migrations` lives inside the database, so migration history is preserved. The master user `brindladmin` can stay as is.
- [ ] Put Doppler into production: sync the `prd` config to AWS Secrets Manager and reference it from the ECS task definition's `secrets` field (supersedes the Terraform note above)
- [ ] Fix `db.NewPostgresStorage` building the connection string without quoting, so a DB user/password containing a space or quote breaks the connection

## Features

- [ ] Action History feature
- [ ] Consider multiple subjects per task (e.g., feed all 4 ferrets as one task instead of per-enclosure)
- [ ] Permanent pet ownership transfer (request/accept flow between users)
- [ ] Temporary ownership transfer for pet sitters (time-bound access with configurable permissions)
