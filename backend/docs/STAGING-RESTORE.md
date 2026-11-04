# Restore rehearsal target

Approved purpose: a separate Supabase project for recovery/check-in testing.
Source: `bofoowyzlnfhwcstlmgp` (website). Target provided by the user:
`orxbprfixonwdwgjqmpv`. These identifiers are different. The user supplied the
target SQL Editor preflight: PostgreSQL 17.11, zero Auth users/application tables,
no website profile/ledger/chatbot schema. Extension versions are recorded in
`evidence/staging-preflight-orxbprfixonwdwgjqmpv.json`. This is user-reported target
evidence, not a direct agent database connection or a source-backup compatibility result.

## Current evidence

- Source backup: `private-backups/before-checkins-20261104T073010550310Z/database.zip.age`.
- Local SHA-256: `0e785b0b3f2b5a5b4da7c8f35fbc42754048b733079958e035b7ac2d06159855`.
- Local age authentication, ZIP CRC, content hashes and offline pg_restore parsing
  passed during the user's backup command. The local ciphertext hash was independently
  matched to verification.json. Application snapshot restore has since passed
  on staging; full platform recovery remains untested.
- Encrypted backup copied to the user's private Google Drive folder (location kept outside Git).
  UI observation confirmed database.zip.age and verification.json were present.
  User confirmed upload/download. A cloud-download checksum was not independently
  verified; no claim of downloaded-copy authentication is made. User asked to move on.
- The migration and RLS passed a native PostgreSQL 17.11 rehearsal on an exclusive
  loopback synthetic cluster; see `evidence/checkins-postgres-rehearsal.json`.
  Synthetic dump/restore is not real Supabase backup restore coverage.

## Target inspection completed; next: offline backup inventory

Open the SQL Editor of target `orxbprfixonwdwgjqmpv` and run
`sql/staging_restore_preflight.sql`. It returns server version, extension versions,
application table names and Auth user count. It contains no writes or private rows.
The dashboard URL is the operator's target check; a literal project ID printed in
a SQL query would not prove the database identity and is deliberately omitted.

Expected initial state: database postgres, no Auth users/application tables,
no website public.users/Prisma ledger, no chatbot schema. Platform Auth/Storage
objects in a newly created Supabase project already exist; they are not an empty
PostgreSQL database. Metadata inspection does not authorize dropping/replacing them.

Inspect source backup metadata/index with an interactive local command:

```powershell
Set-Location 'D:\Kuliah\Semester 7\CAPSTONE DESIGN AND PROJECT\capstone\backend'
& '.\.venv\Scripts\python.exe' -B -m tools.inspect_restore_backup
```

Only the existing backup passphrase is entered at the native age prompt. No DB
password, URL, new export or upload is requested. The tool opens the existing
encrypted archive in memory, checks its reference/content hashes, reads metadata
and runs offline pg_restore --list. It prints selected versions, extension
differences, object counts and selected COPY row counts; never rows, role SQL,
trigger bodies or the index. Data-only SQL is rendered and counted only in memory.
Missing COPY entries are reported as null/unverified, never assumed zero.
It saves the sanitized report to `evidence/staging-backup-inspection.json`.
It never connects to either database and has no restore/migration execution mode.
Compare this inventory against the target before preparing the exact import
list/SQL. Matching extension versions is not proof that managed schemas or Auth
service migration history are compatible; the selection still needs review.

Do not run an unfiltered pg_restore against this newly provisioned target: managed
schemas/roles/extension baseline can collide. Do not use --clean, --create, blanket
role replacement, --no-owner or --no-acl as shortcuts and then claim full parity.
Keep website runtime config unchanged. Restore and check-in migration on the target
are separate operations from applying anything on the source database.

## Reviewed application snapshot and operator command

The completed offline report is `evidence/staging-backup-inspection.json`:
source and target PostgreSQL 17.11 and all five extension versions match.
Archive data: 6 Auth users, 6 identities, 6 profiles, 2 website migration rows;
Storage buckets/objects and Vault secrets have zero archived COPY records.
Only two public application tables, two public functions and two custom Auth
triggers are present. The user's staging command completed at
2026-11-04T15:50:31.094630+00:00; the local report
`evidence/staging-application-restore.json` records a confirmed, verified commit
with those row counts. This is operator-executed evidence, not an agent database
connection. Subsequent two-account login/profile, live check-in write/isolation
and fresh-process readback tests all passed through in-process FastAPI routes.

### Next step: two-account login and profile isolation on staging

```powershell
Set-Location 'D:\Kuliah\Semester 7\CAPSTONE DESIGN AND PROJECT\capstone\backend'
& '.\.venv\Scripts\python.exe' -B -m tools.verify_staging_auth
```

Supply the staging project's **publishable key** and the existing passwords of
Admin Tester and Tester Kedua through hidden prompts. Restored account passwords
are the original tester passwords. No secret/service-role key or database password
is needed. The project URL is pinned to staging and Settings disables .env reads.
The tool runs the real FastAPI /me route in-process through ASGI with live staging
Auth/Data API requests; it does not test an HTTP listener, proxy or deployed server.
It checks missing-token rejection, both sessions/UUIDs and exact /me profiles,
active PARTICIPANT status, and direct cross-profile SELECT invisibility in both
directions. Login creates Auth sessions; tokens/passwords are not written or printed.
There are no profile/check-in writes or migrations. A successful operator run saves
`evidence/staging-auth-verification.json`; synthetic local tests are not live evidence.

The user's run passed at 2026-11-04T15:59:32.648604+00:00, recorded in that report.
The user subsequently supplied the staging post-migration metadata: version
`202611040001_checkins`, applied_at `2026-11-04T16:04:30.087696+00:00`, both tables
with RLS, three owner/active-PARTICIPANT policies, six constraints, expected
authenticated/anon/service_role grants and the prepare-row trigger. The user
confirmed adding `chatbot` to Data API Exposed schemas. Those metadata/settings
are operator-reported evidence. The subsequent live check-in results are below.

### Next step: staging check-in write and process readback

```powershell
Set-Location 'D:\Kuliah\Semester 7\CAPSTONE DESIGN AND PROJECT\capstone\backend'
& '.\.venv\Scripts\python.exe' -B -m tools.verify_staging_checkins --date 2000-01-01
```

Supply staging's publishable key, then both existing tester passwords. This wrapper
reuses the established two-account check-in workflow through the actual FastAPI
routes with a fresh in-process ASGI application. It pins the upstream to staging,
disables .env loading, rejects other direct destinations and never uses port 8001.
Login creates staging sessions; the normal mode writes two synthetic check-ins,
updates one without duplicating its ID and clears its note. It checks validation,
direct Data API read isolation and rejects attempted cross-user writes in both
directions. It requires an empty test date on BOTH accounts before any check-in
POST, prints no private values and does not retry or clean up automatically.
If a run stops after writing, inspect its outcome instead of repeating write mode.

After success, use a separate command/process to read back the same final values:

```powershell
& '.\.venv\Scripts\python.exe' -B -m tools.verify_staging_checkins --date 2000-01-01 --verify-only
```

The readback process creates a new app and logs in again but does not write any
check-ins. It verifies durable readback with direct Data API matching and read RLS;
it does not repeat write rejection tests or test a listening HTTP server, Flutter,
proxy or deployment. Success reports are respectively
`evidence/staging-checkins-verification.json` and `evidence/staging-checkins-readback.json`.
They are generated only after successful operator execution; preparation and
synthetic tests do not establish live persistence. No migrations, profile changes,
privileged keys or website requests are part of either command.

Do not use `tools.verify_checkins` directly for this staging sequence: that original
operator command reads the normal backend .env and sends to port 8001. The staging
wrapper supplies its own pinned configuration and an internal route adapter.

Operator evidence now confirms write/isolation success at
2026-11-04T16:13:57.598511+00:00 and fresh-process readback success at
2026-11-04T16:15:31.116099+00:00 for staging and test date 2000-01-01. Both local
reports were inspected. The false write-test flags in the readback report mean
those checks were not repeated in read-only mode; the earlier write report
records their successful execution. HTTP listener and Flutter tests remain pending.

### Next step: local HTTP server connected to staging

```powershell
Set-Location 'D:\Kuliah\Semester 7\CAPSTONE DESIGN AND PROJECT\capstone\backend'
& '.\.venv\Scripts\python.exe' -B -m tools.serve_staging
```

Enter staging's publishable key through the hidden prompt, then keep that terminal
open and visit http://127.0.0.1:8002/docs. The launcher pins the Supabase target,
disables .env reads, binds only local loopback and disables request access logging.
It uses a single server process without reload and does not change the port-8001
server. Starting it performs no migration or check-in write. Protected routes
require a staging user access token. Swagger availability alone does not prove
authenticated HTTP behavior or mobile integration; those are subsequent checks.
This loopback address is for the developer laptop, not a physical phone deployment.

After the operator starts the server, run authenticated HTTP readback in a second
terminal (the server terminal stays open):

```powershell
Set-Location 'D:\Kuliah\Semester 7\CAPSTONE DESIGN AND PROJECT\capstone\backend'
& '.\.venv\Scripts\python.exe' -B -m tools.verify_staging_http --date 2000-01-01
```

Provide staging's publishable key and both tester passwords through hidden prompts.
The tool checks /me over HTTP for both exact profiles and reuses the read-only
check-in workflow against port 8002, comparing history to the live staging Data API
and checking direct read isolation. Its adapter permits POST only to staging Auth
login; all check-in/profile writes are rejected locally. No token or private row
is printed. Success saves `evidence/staging-http-verification.json`.
An unauthenticated agent probe observed /docs and /openapi.json HTTP 200 and /me
and /checkins HTTP 401 on port 8002; authenticated HTTP testing remains pending
at preparation time. The operator subsequently completed it successfully at
2026-11-04T16:25:04.229691+00:00; `evidence/staging-http-verification.json` was inspected.
HTTP POST check-in, Flutter and public
deployment remain separate coverage from the HTTP readback.

Windows/browser handover: `FLUTTER-INTEGRATION-HANDOVER.md`. The staging launcher
now permits only localhost:7357 and 127.0.0.1:7357 web origins with explicit
methods/headers; restart the launcher to activate this addition. Authenticated
browser preflight/UI behavior is not established by the earlier HTTP CLI evidence.

Run the prepared restore from a private interactive PowerShell terminal:

```powershell
Set-Location 'D:\Kuliah\Semester 7\CAPSTONE DESIGN AND PROJECT\capstone\backend'
& '.\.venv\Scripts\python.exe' -B -m tools.restore_staging --apply
```

Inputs: URI from **Connect on staging**, staging database password (both hidden),
then the existing backup passphrase at the native age prompt. The URI must name
`orxbprfixonwdwgjqmpv` via direct/session mode port 5432. Source/other project
connections are rejected before connecting. Existing CA bundle is reused with
verify-full; `--ca <public-CA-bundle-path>` is available if staging requires a
different trusted CA. Never lower TLS verification or reset a password as a workaround.
No new application .env is created and the website configuration stays unchanged.

If `DATABASE_LOGIN_FAILED` appears before the target verification message, the
initial read-only connection was rejected: no restore SQL has been sent. Recopy
the URI from Connect on the staging project and verify that project's database
password. Leave `[YOUR-PASSWORD]` in the URI; enter the actual password separately
without quoting or URL encoding. The tester login password, source database
password and backup passphrase are separate credentials. The CLI now distinguishes
failure before writing, an unconfirmed apply outcome, and a confirmed commit.

Default command without --apply performs a live read-only staging preflight and
offline plan only. --apply is the explicit operator action writing staging.
The preflight is repeated immediately before import; existing application data,
users/identities, custom Auth triggers, unexpected privileges or version differences
stop the operation. Do not retry automatically after an unconfirmed commit outcome.

### Scope and deliberate differences from the source

This is **application/email-account recovery**, not a full platform clone:

- Restore public application types, two tables, two functions, constraints,
  indexes, RLS/policies, source column/table ACLs and both custom Auth triggers.
- Copy auth.users/auth.identities, public.users and public._prisma_migrations.
  Preserve UUIDs, archived account fields and password hashes without printing them.
- Keep target managed schemas, extension baseline, Auth migration history and
  global roles. Auth migration rows must match the source exactly; they are not
  replaced. SSO/MFA/other unreviewed nonempty configuration stops preparation.
- Do not activate source sessions/refresh tokens/audit/flow history on staging.
  Users log in again. OAuth/SMTP/provider configuration, signing keys, platform
  configuration and full auth-session restoration remain outside this rehearsal.
- Preserve the target public schema baseline. Source global/default ACLs are not
  cloned. Revoke target default table/function grants on newly created application
  objects, then replay source ACLs separately: PostgreSQL archive ACL entries
  can belong to pre-data, so a simple pre/post split would lose column privileges.
- Restrict the restored legacy Prisma ledger from PUBLIC/anon/authenticated/
  service_role, including column grants. This deliberately hardens staging rather
  than claiming exact original privilege parity. Owners retain operator access.

### Transaction and verification

Generated SQL is supplied through stdin, never stored as plaintext SQL/dump.
Temporary local selection files contain numeric archive IDs only. It locks the
two target Auth tables while checking emptiness, imports data before installing
custom signup triggers, restores constraints and ACLs, then checks within the same
transaction. Temporary expected-data tables live only in the staging DB session.
EXCEPT ALL over typed JSON row representations compares every imported source
column against the archived values, without returning private values to the user.
The target Auth migration set must also match. Profile identity links, RLS,
trigger count and runtime column/hash/ledger privileges are checked before COMMIT.
psql ON_ERROR_STOP stops errors; the open transaction rolls back when the failed
connection ends. A lost connection at commit may leave the outcome unknown;
stop and inspect instead of running an overwrite/reset/retry.

Success report: `evidence/staging-application-restore.json`, status
`STAGING_APPLICATION_SNAPSHOT_COMMITTED_AND_VERIFIED`. It explicitly records that
full platform recovery and actual Auth login testing have not been done, and that
the check-in migration has not been applied. Follow with two-account Auth login,
then check-in migration/testing on staging; source deployment requires its own
review/approval. A source migration is never part of this command.

### Local validation

306 synthetic Python tests pass with warnings treated as errors after adding the
staging check-in wrapper; this does not imply a live check-in test. The restore
rehearsal originally passed 277 tests and pip check. `python -B -m tools.rehearse_restore` also exercises an exclusive local
PostgreSQL 17.11 cluster with synthetic data and a non-superuser postgres role:
numeric archive selection, rollback on late errors/baseline mismatch, snapshot
restore, exclusion of old sessions, protection against broad target defaults,
profile RLS, repeat-import rejection, and both restored Auth triggers. Evidence:
`evidence/staging-restore-native-rehearsal.json`. No real backup, hosted connection
or source application data was used by that test.

References:
- https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore
- https://www.postgresql.org/docs/17/app-pgrestore.html
