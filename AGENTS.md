# AGENTS.md

## Project

Super Pomodoro is a desktop-first focus application built with Tauri, Rust, and Svelte. The project combines Pomodoro sessions, task management, sync integrations, and system-level domain blocking and monitoring.

## Source of Truth

- Read the docs in `docs/` before making material product or architecture changes.
- Treat SQLite as the source of truth for application state.
- Treat `docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE_SCHEMA.md`, and `docs/CODING_STANDARDS.md` as the implementation baseline.

## Implementation Approach

- Follow Test-Driven Development (`TDD`) for implementation work.
- Default workflow: `red -> green -> refactor`.
- Start behavior changes by writing or updating a failing test first.
- Implement the smallest change necessary to make the test pass.
- Refactor only after the test suite is green.
- When fixing regressions, add a regression test before or alongside the fix.
- If a change cannot reasonably be tested yet, document the gap clearly in the PR or task notes.

## Architecture Boundaries

- Keep business logic in Rust.
- Keep the Svelte frontend focused on presentation, interaction, and view state.
- Keep Tauri commands thin and orchestration-focused.
- Isolate platform-specific blocking and monitoring logic behind clear interfaces.
- Keep the privileged helper out of the main database write path unless explicitly documented otherwise.

## Database Rules

- Introduce schema changes only through migrations.
- Do not edit previously committed migrations.
- Be careful with high-volume tables such as `domain_access_events`.
- Preserve recovery semantics for sessions, especially `paused`, `interrupted`, and `abandoned` states.

## Sync and Security Rules

- Sync must remain optional and must not block local usage.
- Store secrets securely and never log tokens or sensitive payloads.
- Keep helper IPC narrow, authenticated, and versioned.
- Treat browsing and monitoring data as privacy-sensitive.

## Quality Bar

- Add or update tests with behavior changes.
- Prefer small, reviewable changes.
- Update documentation when changing product behavior, architecture, schema, or helper protocol.
- Preserve accessibility and keyboard support in user-facing flows.
