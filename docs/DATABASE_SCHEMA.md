# Database Schema

## Document Control

- Product: Super Pomodoro
- Version: 0.1
- Status: Draft
- Last updated: 2026-03-13

## Purpose

This document defines the durable local data model for Super Pomodoro. SQLite is the source of truth for user-visible application state. The schema is designed around four priorities:

- reliable session recovery
- explicit sync mappings
- auditable domain blocking and monitoring
- bounded growth for high-volume event data

## Operational Decisions

### Storage Model

- SQLite is the authoritative store for domain data and product settings.
- The privileged helper is not a normal SQLite client for the main database.
- The main Tauri app is the primary database writer.
- The helper communicates events and enforcement state over IPC.
- If the helper must persist while the app is offline, it writes to a helper-local spool file that is flushed into SQLite when the app reconnects.

### SQLite Mode

- `journal_mode = WAL`
- `foreign_keys = ON`
- `busy_timeout` is set to tolerate short-lived write contention
- `auto_vacuum = INCREMENTAL`

WAL is planned because it gives better read concurrency for UI, sync jobs, and analytics while the app is writing session and monitoring data. Since the helper will not directly write the main database, we avoid most of the sharp edges of multi-process SQLite writes.

### Timestamp Rules

- All timestamps are stored in UTC ISO 8601 format.
- Durations are stored as integer seconds.
- Enumerations are stored as constrained text values.

## Core Entity Design

### FocusMode

`FocusMode` is a named preset, not an ad hoc runtime blob.

Examples:

- `Deep Work`: 50/10 timer, strict block lists, monitoring enabled
- `Light Focus`: 25/5 timer, minimal blocking
- `Planning`: 30/10 timer, no blocking, analytics still enabled

Each mode can define:

- timer defaults
- pause behavior
- default blocking policy
- monitoring level

### FocusPlan

`FocusPlan` is a scheduled future intent to focus. It is distinct from a completed session.

Examples:

- A planned work block for today at 2:00 PM
- A recurring morning focus block
- A calendar-backed work plan that may later create one or more sessions

### Interrupted vs. Abandoned

- `Interrupted` means a session stopped unexpectedly and still has recovery value.
- `Abandoned` means a paused or interrupted session exceeded its recovery window and is no longer considered resumable.

## Tables

### `projects`

Purpose:

- Optional task grouping

Columns:

- `id` TEXT PRIMARY KEY
- `name` TEXT NOT NULL
- `color` TEXT NULL
- `sort_order` INTEGER NOT NULL DEFAULT 0
- `archived_at` TEXT NULL
- `created_at` TEXT NOT NULL
- `updated_at` TEXT NOT NULL

Indexes:

- `projects_name_idx` on `name`

### `tasks`

Purpose:

- Core task record

Columns:

- `id` TEXT PRIMARY KEY
- `project_id` TEXT NULL REFERENCES `projects(id)`
- `title` TEXT NOT NULL
- `notes` TEXT NULL
- `status` TEXT NOT NULL
- `due_at` TEXT NULL
- `estimated_pomodoros` INTEGER NULL
- `completed_at` TEXT NULL
- `archived_at` TEXT NULL
- `deleted_at` TEXT NULL
- `last_worked_at` TEXT NULL
- `created_at` TEXT NOT NULL
- `updated_at` TEXT NOT NULL

Indexes:

- `tasks_status_due_idx` on `(status, due_at)`
- `tasks_project_status_idx` on `(project_id, status)`
- `tasks_updated_idx` on `updated_at`

### `tags`

Purpose:

- Reusable task labels

Columns:

- `id` TEXT PRIMARY KEY
- `name` TEXT NOT NULL
- `color` TEXT NULL
- `created_at` TEXT NOT NULL
- `updated_at` TEXT NOT NULL

Constraints:

- unique `name`

### `task_tags`

Purpose:

- Many-to-many link between tasks and tags

Columns:

- `task_id` TEXT NOT NULL REFERENCES `tasks(id)`
- `tag_id` TEXT NOT NULL REFERENCES `tags(id)`
- `created_at` TEXT NOT NULL

Constraints:

- PRIMARY KEY `(task_id, tag_id)`

### `focus_modes`

Purpose:

- Named timer and blocking presets

Columns:

- `id` TEXT PRIMARY KEY
- `name` TEXT NOT NULL
- `description` TEXT NULL
- `focus_duration_sec` INTEGER NOT NULL
- `short_break_duration_sec` INTEGER NOT NULL
- `long_break_duration_sec` INTEGER NOT NULL
- `long_break_interval` INTEGER NOT NULL
- `pause_behavior` TEXT NOT NULL
- `monitoring_mode` TEXT NOT NULL
- `is_default` INTEGER NOT NULL DEFAULT 0
- `created_at` TEXT NOT NULL
- `updated_at` TEXT NOT NULL

Constraints:

- unique `name`

### `focus_plans`

Purpose:

- Scheduled future focus blocks

Columns:

- `id` TEXT PRIMARY KEY
- `task_id` TEXT NULL REFERENCES `tasks(id)`
- `focus_mode_id` TEXT NOT NULL REFERENCES `focus_modes(id)`
- `title` TEXT NULL
- `scheduled_start_at` TEXT NOT NULL
- `planned_duration_sec` INTEGER NOT NULL
- `timezone` TEXT NULL
- `recurrence_rule` TEXT NULL
- `calendar_sync_enabled` INTEGER NOT NULL DEFAULT 0
- `status` TEXT NOT NULL
- `created_at` TEXT NOT NULL
- `updated_at` TEXT NOT NULL

Indexes:

- `focus_plans_start_idx` on `scheduled_start_at`
- `focus_plans_status_idx` on `status`

### `sessions`

Purpose:

- Durable record of an executed or executing focus or break phase

Columns:

- `id` TEXT PRIMARY KEY
- `task_id` TEXT NULL REFERENCES `tasks(id)`
- `focus_plan_id` TEXT NULL REFERENCES `focus_plans(id)`
- `focus_mode_id` TEXT NOT NULL REFERENCES `focus_modes(id)`
- `phase_kind` TEXT NOT NULL
- `lifecycle_status` TEXT NOT NULL
- `started_at` TEXT NOT NULL
- `target_end_at` TEXT NULL
- `paused_at` TEXT NULL
- `ended_at` TEXT NULL
- `remaining_sec` INTEGER NOT NULL
- `accumulated_active_sec` INTEGER NOT NULL DEFAULT 0
- `last_heartbeat_at` TEXT NOT NULL
- `recoverable_until` TEXT NULL
- `completion_reason` TEXT NULL
- `interruption_reason` TEXT NULL
- `blocking_policy_snapshot_id` TEXT NULL
- `created_at` TEXT NOT NULL
- `updated_at` TEXT NOT NULL

Key recovery columns:

- `lifecycle_status`
- `paused_at`
- `target_end_at`
- `remaining_sec`
- `last_heartbeat_at`
- `recoverable_until`
- `ended_at`

Recovery rule:

- Any row with `ended_at IS NULL` and `lifecycle_status IN ('running', 'paused', 'interrupted')` is a recovery candidate.

Indexes:

- `sessions_status_idx` on `lifecycle_status`
- `sessions_task_idx` on `task_id`
- `sessions_started_idx` on `started_at`
- `sessions_recovery_idx` on `(ended_at, lifecycle_status, recoverable_until)`

### `session_events`

Purpose:

- Immutable audit trail of state transitions

Columns:

- `id` INTEGER PRIMARY KEY
- `session_id` TEXT NOT NULL REFERENCES `sessions(id)`
- `event_type` TEXT NOT NULL
- `from_state` TEXT NULL
- `to_state` TEXT NULL
- `occurred_at` TEXT NOT NULL
- `payload_json` TEXT NULL

Indexes:

- `session_events_session_time_idx` on `(session_id, occurred_at)`

### `domain_groups`

Purpose:

- Named groups of blocked or allowed domains

Columns:

- `id` TEXT PRIMARY KEY
- `name` TEXT NOT NULL
- `description` TEXT NULL
- `group_kind` TEXT NOT NULL
- `archived_at` TEXT NULL
- `created_at` TEXT NOT NULL
- `updated_at` TEXT NOT NULL

Constraints:

- unique `name`

### `domain_rules`

Purpose:

- Matchable domain patterns inside a domain group

Columns:

- `id` TEXT PRIMARY KEY
- `group_id` TEXT NOT NULL REFERENCES `domain_groups(id)`
- `pattern` TEXT NOT NULL
- `normalized_pattern` TEXT NOT NULL
- `match_type` TEXT NOT NULL
- `enabled` INTEGER NOT NULL DEFAULT 1
- `created_at` TEXT NOT NULL
- `updated_at` TEXT NOT NULL

Indexes:

- `domain_rules_group_idx` on `group_id`
- `domain_rules_pattern_idx` on `normalized_pattern`

### `blocking_policies`

Purpose:

- Reusable or generated blocking policy definitions

Columns:

- `id` TEXT PRIMARY KEY
- `name` TEXT NOT NULL
- `source_type` TEXT NOT NULL
- `focus_mode_id` TEXT NULL REFERENCES `focus_modes(id)`
- `schedule_rrule` TEXT NULL
- `block_on_pause` INTEGER NOT NULL DEFAULT 0
- `monitoring_enabled` INTEGER NOT NULL DEFAULT 1
- `emergency_unlock_ttl_sec` INTEGER NULL
- `created_at` TEXT NOT NULL
- `updated_at` TEXT NOT NULL

### `blocking_policy_domain_groups`

Purpose:

- Join table mapping policies to domain groups

Columns:

- `policy_id` TEXT NOT NULL REFERENCES `blocking_policies(id)`
- `domain_group_id` TEXT NOT NULL REFERENCES `domain_groups(id)`
- `action` TEXT NOT NULL
- `priority` INTEGER NOT NULL DEFAULT 100

Constraints:

- PRIMARY KEY `(policy_id, domain_group_id, action)`

Indexes:

- `blocking_policy_groups_priority_idx` on `(policy_id, priority)`

### `blocking_state`

Purpose:

- Current or recent enforcement state reported by the helper

Columns:

- `id` TEXT PRIMARY KEY
- `session_id` TEXT NULL REFERENCES `sessions(id)`
- `policy_id` TEXT NULL REFERENCES `blocking_policies(id)`
- `status` TEXT NOT NULL
- `helper_revision` INTEGER NOT NULL DEFAULT 0
- `activated_at` TEXT NULL
- `deactivated_at` TEXT NULL
- `last_error_code` TEXT NULL
- `last_error_message` TEXT NULL
- `helper_status_json` TEXT NULL
- `updated_at` TEXT NOT NULL

Indexes:

- `blocking_state_status_idx` on `status`

### `domain_access_events`

Purpose:

- High-volume raw monitoring events

Columns:

- `id` INTEGER PRIMARY KEY
- `occurred_at` TEXT NOT NULL
- `normalized_domain` TEXT NOT NULL
- `registrable_domain` TEXT NULL
- `source_process_name` TEXT NULL
- `source_process_path` TEXT NULL
- `session_id` TEXT NULL REFERENCES `sessions(id)`
- `policy_id` TEXT NULL REFERENCES `blocking_policies(id)`
- `matched_rule_id` TEXT NULL REFERENCES `domain_rules(id)`
- `matched_group_id` TEXT NULL REFERENCES `domain_groups(id)`
- `action` TEXT NOT NULL
- `event_kind` TEXT NOT NULL
- `foreground_app` TEXT NULL
- `idle_state` TEXT NOT NULL
- `metadata_json` TEXT NULL

Indexes:

- `domain_events_time_idx` on `occurred_at`
- `domain_events_domain_time_idx` on `(normalized_domain, occurred_at)`
- `domain_events_session_time_idx` on `(session_id, occurred_at)`
- `domain_events_action_time_idx` on `(action, occurred_at)`

Retention strategy:

- Raw events retained for 30 days by default
- User-configurable retention window of 7 to 90 days
- Daily aggregates retained long-term
- Nightly compaction job deletes expired rows, checkpoints WAL, and increments vacuum

### `domain_aggregates_daily`

Purpose:

- Long-lived analytics rollups derived from raw events

Columns:

- `day` TEXT NOT NULL
- `normalized_domain` TEXT NOT NULL
- `matched_group_id` TEXT NULL REFERENCES `domain_groups(id)`
- `allowed_count` INTEGER NOT NULL DEFAULT 0
- `blocked_count` INTEGER NOT NULL DEFAULT 0
- `estimated_active_sec` INTEGER NOT NULL DEFAULT 0
- `estimated_focus_sec` INTEGER NOT NULL DEFAULT 0
- `estimated_distracting_sec` INTEGER NOT NULL DEFAULT 0
- `first_seen_at` TEXT NULL
- `last_seen_at` TEXT NULL

Constraints:

- PRIMARY KEY `(day, normalized_domain, matched_group_id)`

### `provider_accounts`

Purpose:

- Connected provider identities and cursors

Columns:

- `id` TEXT PRIMARY KEY
- `provider_type` TEXT NOT NULL
- `account_external_id` TEXT NOT NULL
- `display_name` TEXT NULL
- `scopes_json` TEXT NULL
- `sync_enabled` INTEGER NOT NULL DEFAULT 1
- `last_sync_cursor` TEXT NULL
- `last_sync_at` TEXT NULL
- `revoked_at` TEXT NULL
- `created_at` TEXT NOT NULL
- `updated_at` TEXT NOT NULL

Constraints:

- unique `(provider_type, account_external_id)`

### `sync_mappings`

Purpose:

- Map local entities to remote entities across providers

Columns:

- `id` TEXT PRIMARY KEY
- `provider_account_id` TEXT NOT NULL REFERENCES `provider_accounts(id)`
- `local_entity_type` TEXT NOT NULL
- `local_entity_id` TEXT NOT NULL
- `remote_entity_type` TEXT NOT NULL
- `remote_entity_id` TEXT NOT NULL
- `remote_namespace` TEXT NULL
- `mapping_role` TEXT NOT NULL DEFAULT 'primary'
- `remote_etag` TEXT NULL
- `remote_updated_at` TEXT NULL
- `last_pushed_at` TEXT NULL
- `last_pulled_at` TEXT NULL
- `metadata_json` TEXT NULL

How one-local-to-many-remote works:

- A single local entity can have multiple rows in this table.
- The row is uniquely identified by provider account, local entity, remote entity type, and mapping role.
- Example:
  - one `task` -> one GitHub `issue` with role `primary`
  - the same `task` -> one Google Calendar `event` with role `deadline_event`
  - one `focus_plan` -> one Google Calendar `event` with role `planned_block`

Constraints:

- unique `(provider_account_id, local_entity_type, local_entity_id, remote_entity_type, mapping_role)`
- unique `(provider_account_id, remote_entity_type, remote_entity_id)`

Indexes:

- `sync_mappings_local_idx` on `(local_entity_type, local_entity_id)`

### `sync_operations`

Purpose:

- Durable sync queue

Columns:

- `id` TEXT PRIMARY KEY
- `provider_account_id` TEXT NOT NULL REFERENCES `provider_accounts(id)`
- `local_entity_type` TEXT NOT NULL
- `local_entity_id` TEXT NOT NULL
- `mapping_id` TEXT NULL REFERENCES `sync_mappings(id)`
- `operation_type` TEXT NOT NULL
- `payload_json` TEXT NOT NULL
- `idempotency_key` TEXT NOT NULL
- `status` TEXT NOT NULL
- `attempt_count` INTEGER NOT NULL DEFAULT 0
- `next_attempt_at` TEXT NULL
- `locked_at` TEXT NULL
- `last_error_code` TEXT NULL
- `last_error_message` TEXT NULL
- `created_at` TEXT NOT NULL
- `updated_at` TEXT NOT NULL
- `completed_at` TEXT NULL

Constraints:

- unique `idempotency_key`

Indexes:

- `sync_operations_status_retry_idx` on `(status, next_attempt_at)`

### `sync_conflicts`

Purpose:

- Persist unresolved reconciliation conflicts

Columns:

- `id` TEXT PRIMARY KEY
- `provider_account_id` TEXT NOT NULL REFERENCES `provider_accounts(id)`
- `local_entity_type` TEXT NOT NULL
- `local_entity_id` TEXT NOT NULL
- `remote_entity_type` TEXT NOT NULL
- `remote_entity_id` TEXT NOT NULL
- `conflict_type` TEXT NOT NULL
- `local_snapshot_json` TEXT NOT NULL
- `remote_snapshot_json` TEXT NOT NULL
- `resolution_status` TEXT NOT NULL
- `detected_at` TEXT NOT NULL
- `resolved_at` TEXT NULL

Indexes:

- `sync_conflicts_open_idx` on `(resolution_status, detected_at)`

### `app_settings`

Purpose:

- Business-critical settings that affect product behavior

Columns:

- `namespace` TEXT NOT NULL
- `key` TEXT NOT NULL
- `value_json` TEXT NOT NULL
- `updated_at` TEXT NOT NULL

Constraints:

- PRIMARY KEY `(namespace, key)`

Examples:

- timer defaults
- default focus mode
- sync preferences
- retention policy
- emergency unlock configuration

`tauri-plugin-store` is not the source of truth for these settings. It is reserved for non-critical UI preferences such as window geometry, last-opened panels, or dismissed onboarding hints.

## Recovery Semantics

### Paused Then Closed

If a session is paused and the app closes:

- `lifecycle_status` remains `paused`
- `remaining_sec` stays frozen
- `paused_at` remains populated
- `ended_at` remains `NULL`

When the app reopens, the session is restored in the paused state with the same remaining time.

### Interrupted

A session becomes `interrupted` when it ends early because of an external condition rather than an explicit user stop.

Examples:

- app crash during a strict session
- helper failure while enforcement is required
- reboot or forced termination before the phase finishes

### Abandoned

A session becomes `abandoned` when:

- it is paused or interrupted
- the user does not resume it
- `recoverable_until` has passed

This is a cleanup and analytics distinction, not just a UI flag.

## Retention and Anti-Bloat Strategy

For `domain_access_events`, growth is controlled through:

- bounded raw retention
- daily rollups in `domain_aggregates_daily`
- incremental vacuum after pruning
- compact integer primary key row ids
- narrowly scoped indexes only on time, domain, session, and action paths

If event volume proves higher than expected, the next optimization step is a domain dictionary table and chunked archival export. That is not required for v1.

## Backup and Recovery Strategy

- Use SQLite's online backup API or `VACUUM INTO` for safe snapshots.
- Create automatic rolling backups on a scheduled cadence.
- Retain the last 7 daily backups and 4 weekly backups by default.
- Run `PRAGMA integrity_check` during maintenance and before pruning old backups.
- If corruption is detected, preserve the damaged database file, offer restore from the latest healthy snapshot, and record the recovery event in diagnostics.

## Migration Rules

- All schema changes must be introduced through versioned migrations.
- Backward-incompatible changes require a documented migration path.
- High-volume table migrations must include a rollback or repair plan.
