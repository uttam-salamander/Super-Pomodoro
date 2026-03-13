# Technical Architecture

## Document Control

- Product: Super Pomodoro
- Version: 0.2
- Status: Draft
- Last updated: 2026-03-13

## Purpose

This document defines the target architecture for Super Pomodoro. It focuses on shared product logic, system boundaries, data ownership, sync design, and platform-specific enforcement for domain blocking and monitoring.

## Architectural Principles

- Local state is the primary source of truth.
- Core behavior should be deterministic, testable, and implemented in Rust where possible.
- Platform-specific enforcement should be isolated behind clear interfaces.
- The UI should remain thin and not directly own business rules.
- External sync providers must be optional and loosely coupled.
- Blocking and monitoring behavior must be explicit, auditable, and reversible.

## Technology Stack

- Desktop shell: Tauri v2
- Frontend: Svelte with Vite
- Core language: Rust
- Async runtime: Tokio
- Database: SQLite
- Database access: SQLx
- Serialization: Serde
- HTTP client: Reqwest
- OAuth: OAuth2 crate plus Tauri deep-link support
- Secure storage: `tauri-plugin-stronghold`
- App settings: `tauri-plugin-store`
- Notifications, updater, autostart: Tauri plugins as needed
- Rust dependency layout: Cargo workspace under `src-tauri/`
- Platform gating: Cargo feature flags and `cfg` modules for OS-specific enforcement

## Repository Layout

```text
/
├── docs/
│   ├── PRD.md
│   ├── ARCHITECTURE.md
│   ├── DIAGRAMS.md
│   └── CODING_STANDARDS.md
├── src/
│   ├── app/
│   ├── features/
│   ├── lib/
│   └── styles/
├── src-tauri/
│   ├── src/
│   │   ├── app/
│   │   ├── commands/
│   │   ├── domain/
│   │   ├── persistence/
│   │   ├── services/
│   │   ├── sync/
│   │   ├── blockers/
│   │   ├── monitoring/
│   │   └── platform/
│   ├── crates/
│   │   ├── core/
│   │   └── helper-protocol/
│   ├── bin/
│   │   └── platform-helper/
│   ├── capabilities/
│   ├── migrations/
│   └── tauri.conf.json
└── README.md
```

## High-Level Component Model

The system is split into five major layers:

### 1. Presentation Layer

- Svelte routes, layouts, and feature screens
- Local view state
- Command invocation and event subscriptions
- No direct OS or network access

### 2. Application Layer

- Tauri commands
- DTO validation
- Permission-aware orchestration
- Translation between UI contracts and domain services

### 3. Domain Layer

- Timer engine
- Task engine
- Focus session policy engine
- Domain blocking policy engine
- Domain monitoring aggregation engine
- Sync planning and reconciliation logic

### 4. Infrastructure Layer

- SQLite repositories
- HTTP clients
- OAuth flow handling
- Secure credential storage
- System notifications
- Logging and metrics

### 5. Platform Enforcement Layer

- Desktop domain blocking helper
- Desktop domain monitoring helper
- OS-specific permission and privilege handling
- Startup and background execution integration

## Core Modules

### Timer Engine

Responsibilities:

- Maintain session lifecycle state
- Apply Pomodoro rules and break cadence
- Emit lifecycle events
- Recover current session after restart
- Compute recovery outcomes from wall-clock time and persisted session data

### Task Engine

Responsibilities:

- Manage task lifecycle
- Link sessions to tasks
- Aggregate task statistics
- Produce sync-ready task deltas

### Sync Engine

Responsibilities:

- Maintain provider accounts and tokens
- Plan outbound operations
- Pull inbound changes
- Reconcile remote and local state
- Surface conflicts for user review

### Blocking Engine

Responsibilities:

- Compile active domain policies
- Resolve schedules and session-triggered rules
- Produce platform-ready block sets
- Track emergency unlock state

### Monitoring Engine

Responsibilities:

- Ingest raw access events
- Normalize domain names and rule matches
- Produce daily and session-level aggregates
- Estimate active time from network and local activity signals

## Shared Domain Model

Primary entities:

- `Project`
- `Task`
- `TaskStatus`
- `Tag`
- `TaskTag`
- `FocusMode`
- `Session`
- `SessionPhase`
- `FocusPlan`
- `DomainGroup`
- `DomainRule`
- `BlockingPolicy`
- `BlockingState`
- `DomainAccessEvent`
- `DomainAggregate`
- `ProviderAccount`
- `SyncMapping`
- `SyncOperation`
- `SyncConflict`

## Focus Mode Model

`FocusMode` is a named preset that combines timer behavior and attention policy.

Each mode may define:

- focus and break durations
- long-break cadence
- pause behavior
- default blocking policy
- monitoring mode

Examples:

- `Deep Work`
- `Light Focus`
- `Planning`

This keeps user intent stable and syncable instead of recalculating policy from transient UI choices alone.

## Data Ownership

- SQLite owns durable application state.
- Stronghold owns sensitive credentials and refresh tokens.
- External systems own their own identifiers and metadata, but local mappings remain authoritative for the app.
- Platform helpers own active OS-level enforcement state, but they must report status back to the app.

## Persistence Model

Suggested tables:

- `projects`
- `tasks`
- `tags`
- `task_tags`
- `focus_modes`
- `focus_plans`
- `sessions`
- `session_events`
- `domain_groups`
- `domain_rules`
- `blocking_policies`
- `blocking_policy_domain_groups`
- `blocking_state`
- `domain_access_events`
- `domain_aggregates_daily`
- `provider_accounts`
- `sync_mappings`
- `sync_operations`
- `sync_conflicts`
- `app_settings`

See [Database Schema](./DATABASE_SCHEMA.md) for table-by-table definitions, keys, retention strategy, recovery columns, WAL usage, and backup planning.

## Session State Model and Recovery

### Two Dimensions

Sessions are modeled with two dimensions:

- `phase_kind`: `focus`, `short_break`, `long_break`
- `lifecycle_status`: `running`, `paused`, `completed`, `cancelled`, `interrupted`, `abandoned`

### Recovery Behavior

- If a user pauses a focus phase and closes the app, the session remains `paused` and retains the same `remaining_sec`.
- If a user reopens the app, that paused session is restored as paused and is not auto-resumed.
- `Interrupted` means the phase ended or became invalid because of an external condition rather than an explicit user stop.
- `Abandoned` means a paused or interrupted session exceeded its recovery window and is no longer treated as resumable.

### Why `Interrupted` and `Abandoned` Both Exist

- `Interrupted` captures unexpected failure or disruption and preserves recovery context.
- `Abandoned` is a later outcome used for cleanup and analytics when the user never returns to recover the session.

## Settings Source of Truth

- `app_settings` in SQLite is authoritative for product behavior such as timer defaults, retention policy, focus modes, sync settings, and enforcement behavior.
- `tauri-plugin-store` is used only for non-critical UI preferences such as window size, split panes, and dismissed tips.
- If the two disagree, SQLite wins for any behavior that affects domain logic.

## Database Access Strategy

- The main app is the primary writer to the SQLite database.
- The helper does not directly write the main database during normal operation.
- Helper events are sent over IPC and persisted by the main app.
- If the app is unavailable, the helper may buffer to a helper-local spool and flush later.

This avoids most multi-process lock contention and keeps migrations, integrity checks, and backups under one owner.

## Domain Blocking Architecture

### Blocking Design Goal

Block domains across browsers and normal desktop apps by enforcing rules below the browser layer.

### Design Approach

- The UI defines domain groups and policy intent.
- The Rust core resolves active policies for the current session and schedule.
- A platform helper applies the effective policy to the operating system.
- The helper reports applied state, failures, and audit events back to the app.

### Platform Strategy

#### Windows

- Use a dedicated helper or service for domain enforcement.
- Prefer native network controls over browser-specific behavior.
- Support fallback strategies such as hosts-file management only when the main mechanism is unavailable.

#### macOS

- Use the platform's network filtering or DNS control model where available.
- Expect code-signing, entitlement, and approval requirements.
- Keep the enforcement adapter separate from the main app lifecycle.

#### Linux

- Use a root-level helper with a distro-aware enforcement strategy.
- Expect differences between distributions and package managers.
- Treat Linux enforcement details as an adapter concern rather than core product logic.

Linux implementation specifics are intentionally deferred because they depend heavily on distribution and deployment model.

### Blocking Policy Compilation

Policy inputs:

- Active focus session
- User-selected focus mode
- Scheduled blocking windows
- Emergency unlock state
- Allowlisted domains
- App-required domains

Policy output:

- Resolved explicit domains
- Resolved wildcard patterns
- Block action
- Allow action
- Effective start time
- Effective end time
- Audit context

## IPC Between Main App and Helper

### Planned Mechanism

- macOS and Linux: Unix domain sockets
- Windows: named pipes
- Payloads: versioned `serde` request and event envelopes over a framed local RPC protocol

### Why This Over a Local HTTP Server

Benefits:

- local-only transport with no TCP port exposure
- OS-native ACLs and ownership checks
- lower accidental attack surface
- no loopback port conflicts, proxy interaction, or firewall oddities

Trade-offs:

- requires platform-specific transport abstraction
- slightly harder to inspect manually than plain HTTP
- pipe and socket lifecycle management must be handled carefully

### Why Not Use Local HTTP as the Primary Protocol

- loopback listeners create a larger attack surface
- port binding and discovery become another operational problem
- auth and origin concerns become more complex for a privileged service

### Security Expectations

- Restrict transport endpoints to the local user and helper service account where supported
- Perform a versioned handshake before accepting commands
- Authenticate control messages using an install-scoped secret or equivalent local trust mechanism
- Keep the command surface minimal: apply policy, query status, stream events, flush spool, heartbeat

## Domain Monitoring Architecture

### Monitoring Design Goal

Capture domain access events system-wide and compute useful, honest analytics without claiming impossible precision.

### Monitoring Pipeline

1. The platform helper observes domain access or connection intent.
2. Raw events are normalized into a shared event schema.
3. Events are stored locally.
4. Aggregation jobs compute daily rollups and session-linked summaries.
5. The analytics layer estimates active time using heuristics.

### Time Estimation Strategy

Inputs:

- Domain access events
- Session state
- Foreground application state where available
- User idle state where available

Outputs:

- Estimated active minutes by domain
- Estimated distracting minutes by day
- Blocked attempt counts
- Session-level distraction summaries

The system must label these metrics as estimates whenever they are not derived from exact browser-tab instrumentation.

## Sync Architecture

### Local-First Sync Model

- Local changes are committed immediately.
- Outbound sync work is enqueued as idempotent operations.
- Provider adapters translate local entities into remote operations.
- Remote updates are pulled into staging and reconciled against local records.
- Conflicts are persisted and surfaced for explicit user resolution.

### Provider Model

Provider adapters implement a shared contract:

- `connect`
- `refresh_account`
- `push_changes`
- `pull_changes`
- `resolve_remote_reference`
- `reconcile`

### GitHub Provider

- Sync local tasks to GitHub issues
- Map task completion to issue state
- Support issue comments for session summaries where appropriate

### Google Calendar Provider

- Sync scheduled focus blocks and task deadlines to calendar events
- Treat calendar events as schedule projections rather than task ownership

## Backup and Integrity Strategy

- Enable rolling database backups using SQLite-safe snapshot mechanisms
- Run scheduled integrity checks
- Preserve corrupted files before restore attempts
- Keep restore behavior explicit and user-visible

## Security Model

### Tauri Capabilities

- Windows and views must receive only the capabilities they need.
- Dangerous shell access must not be exposed to the frontend.
- Blocking and monitoring commands should be narrow, explicit, and auditable.

### Secrets

- Access tokens and refresh tokens must be stored in Stronghold.
- Sensitive tokens must never be logged.
- Provider access should be revocable at any time.

### Local Data

- Browsing data and productivity metrics must be easy to inspect and delete.
- Exports should contain only user-visible fields unless a diagnostic export is explicitly requested.

## IPC and Eventing

### Command Style

- Commands should be small, explicit, and feature-oriented.
- Long-running operations should run in background tasks and report progress via events.
- The frontend should not poll aggressively when event subscriptions are available.

### Event Categories

- Timer events
- Task events
- Sync events
- Blocking state events
- Monitoring aggregate events
- System health events

## Error Handling Strategy

- Domain services return typed errors.
- Command boundaries translate domain errors into user-safe messages and machine-readable codes.
- Platform helpers return structured status rather than unparsed strings.
- Sync retries must use backoff and circuit-breaking behavior for repeated failures.

## Packaging and Runtime Model

### Main App

- Hosts the UI and core orchestration
- Owns data and settings
- Invokes helpers and provider flows

### Privileged Helper

- Applies OS-level domain controls
- Observes access events where supported
- Runs with only the privileges required for enforcement
- Exposes a tightly scoped local control channel

### Upgrade Strategy

- The app and helper should be versioned together.
- Upgrade compatibility should be validated for database schema and helper protocol.
- Emergency rollback should disable enforcement cleanly if startup checks fail.

## Observability

- Use structured logging in Rust
- Separate operational logs from user-visible history
- Track helper heartbeat and enforcement status
- Record sync queue health and failure counts

## Test Strategy Summary

- Unit test domain logic extensively
- Integration test repositories and sync adapters
- Contract test platform helper protocols
- End-to-end test focus, task, sync, and blocking flows on primary target platforms

See [Coding Standards](./CODING_STANDARDS.md) for implementation rules and testing expectations, and [System Diagrams](./DIAGRAMS.md) for detailed visual views.
