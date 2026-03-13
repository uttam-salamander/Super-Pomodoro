# Implementation Plan

## Purpose

This plan translates the PRD and architecture into an execution backlog with clear sequencing. It is designed for TDD-first delivery with CI/CD and quality gates active from day one.

## Delivery Principles

- Follow TDD for all behavior changes.
- Ship in thin vertical slices.
- Keep local-first behavior reliable before adding remote integrations.
- Preserve security and privacy boundaries while adding helper capabilities.

## Phase 0: Engineering Foundation

Goals:

- Establish local Git hooks and CI/CD scaffolding.
- Add issue templates and labels for a consistent workflow.
- Establish scaffolding standards for Rust workspace and Svelte frontend.

Exit criteria:

- Hooks run fast checks on commit and full checks on push.
- CI runs markdown lint and repository checks on push and PR.
- CD workflow exists as a release scaffold with preflight checks.

## Phase 1: App Scaffolding and Core Domain

Goals:

- Scaffold Tauri + Svelte + Rust project structure.
- Implement timer state machine and session recovery.
- Implement foundational SQLite migrations and repositories.

Exit criteria:

- Timer transitions are covered by unit tests.
- Session recovery behavior is deterministic and tested.
- Schema and migrations match database design docs.

## Phase 2: Tasks, Focus Modes, and Plans

Goals:

- Implement task CRUD, tags, projects, and lifecycle status.
- Implement focus modes and focus plans.
- Connect timer sessions to tasks and plans.

Exit criteria:

- Core task flows are tested end-to-end.
- Focus mode selection affects timer and policy decisions.
- Focus plan records are persisted and queryable.

## Phase 3: Blocking and Monitoring Foundations

Goals:

- Implement helper IPC protocol crate.
- Implement policy compilation in Rust core.
- Implement helper status heartbeat and enforcement lifecycle.
- Ingest and aggregate domain access events.

Exit criteria:

- Helper protocol is versioned and contract-tested.
- Blocking state transitions are auditable.
- Monitoring rollups produce daily analytics outputs.

## Phase 4: Sync Providers

Goals:

- Implement provider account linking.
- Implement sync queue with idempotent operations and retries.
- Implement GitHub issue mapping.
- Implement Google Calendar event mapping.

Exit criteria:

- Sync operations are durable and retryable.
- Mapping table supports one local entity to many remote entities.
- Conflict states are persisted and visible.

## Phase 5: Hardening and Release

Goals:

- Expand integration and e2e coverage.
- Add release build jobs and signing strategy.
- Validate backup and restore workflows.

Exit criteria:

- Quality gates pass for target platforms.
- Release jobs are reproducible.
- Restore path is documented and tested.

## Issue Backlog

Phase 0:

- [#1 Scaffold Tauri + Svelte workspace and Rust workspace layout](https://github.com/uttam-salamander/Super-Pomodoro/issues/1)
- [#13 Harden CD to production release matrix and signing](https://github.com/uttam-salamander/Super-Pomodoro/issues/13)

Phase 1:

- [#2 Implement timer state machine and recovery semantics (TDD)](https://github.com/uttam-salamander/Super-Pomodoro/issues/2)
- [#3 Create SQLite migrations for core domain tables and indexes](https://github.com/uttam-salamander/Super-Pomodoro/issues/3)

Phase 2:

- [#4 Implement task management services and repositories](https://github.com/uttam-salamander/Super-Pomodoro/issues/4)
- [#5 Implement FocusMode and FocusPlan flows](https://github.com/uttam-salamander/Super-Pomodoro/issues/5)

Phase 3:

- [#6 Define versioned helper IPC protocol crate](https://github.com/uttam-salamander/Super-Pomodoro/issues/6)
- [#7 Implement blocking policy compilation engine](https://github.com/uttam-salamander/Super-Pomodoro/issues/7)
- [#8 Build privileged helper skeleton with heartbeat and status](https://github.com/uttam-salamander/Super-Pomodoro/issues/8)
- [#9 Implement domain monitoring ingestion and daily rollups](https://github.com/uttam-salamander/Super-Pomodoro/issues/9)

Phase 4:

- [#10 Implement sync queue and mapping model](https://github.com/uttam-salamander/Super-Pomodoro/issues/10)
- [#11 Implement GitHub Issues provider adapter](https://github.com/uttam-salamander/Super-Pomodoro/issues/11)
- [#12 Implement Google Calendar provider adapter](https://github.com/uttam-salamander/Super-Pomodoro/issues/12)
