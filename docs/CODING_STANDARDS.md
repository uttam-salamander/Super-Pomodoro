# Coding Standards

## Purpose

These standards define how Super Pomodoro should be implemented so the codebase stays predictable, secure, and easy to evolve. The project combines a Svelte frontend, a Tauri application shell, a Rust core, and platform-specific helpers.

## General Standards

- Optimize for clarity before cleverness.
- Keep shared business rules in Rust, not duplicated across frontend and backend.
- Prefer small modules with explicit responsibilities.
- Write code that is testable without a live UI or live external provider.
- Use ASCII by default unless a file already requires Unicode.
- Keep comments brief and only when they add meaning not obvious from the code.

## Architecture Rules

- The frontend must not contain core business logic.
- Tauri commands must orchestrate domain services rather than implement domain rules inline.
- Platform-specific enforcement code must be isolated behind traits or adapter interfaces.
- External provider logic must live behind provider interfaces and never bleed into unrelated modules.
- Persistence models must not become the domain model.

## Documentation Rules

- Update the PRD and architecture docs when product scope or system boundaries change materially.
- Add or update diagrams when a new subsystem or protocol is introduced.
- Record meaningful architecture decisions in docs before large implementation changes land.

## Rust Standards

### Project Structure

- Organize backend code by feature and layer.
- Keep pure domain code free from Tauri types where practical.
- Put OS-specific code behind `cfg` gates and platform adapter modules.

### Language and Tooling

- Target stable Rust.
- Run `cargo fmt` on all Rust changes.
- Run `cargo clippy --all-targets --all-features` before merging meaningful backend work.
- Use `rust-analyzer` friendly project structure and avoid macro-heavy patterns without strong justification.

### Error Handling

- Never use `unwrap` or `expect` in production paths except where a crash is intentionally unrecoverable and documented.
- Use typed domain errors with `thiserror`.
- Use `anyhow` only at application boundaries or for short-lived internal tooling.
- Include actionable context on infrastructure errors.

### Async and Concurrency

- Use async only for real I/O or coordination needs.
- Keep CPU-heavy work off async executors where appropriate.
- Protect shared mutable state behind clear ownership boundaries.
- Prefer message passing and explicit state machines over ad hoc locks.

### Time and Dates

- Store timestamps in UTC.
- Convert to local time only for display.
- Keep duration math explicit and tested.

## Database Standards

- Use SQLite as the local source of truth.
- Enable WAL mode for the main application database.
- Manage schema changes through versioned migrations only.
- Never edit historical migrations after they have been committed.
- Keep repository methods focused and predictable.
- Use transactions for multi-step state transitions.
- Index fields used in task lists, session history, sync queues, and analytics queries.
- Keep the privileged helper out of the main database write path unless a documented exception exists.
- Define retention and compaction behavior for high-volume tables before shipping them.
- Use SQLite-safe backup mechanisms rather than raw file copies of a live database.

## Dependency and Workspace Standards

- Organize Rust code as a Cargo workspace rooted in `src-tauri/`.
- Put shared contracts such as helper IPC types into small dedicated crates.
- Use feature flags for platform-specific integrations and helper binaries.
- Commit lockfiles for Rust and frontend dependencies.
- Add new dependencies only when the team can explain why the standard library or an existing crate is insufficient.

## CI and Automation Standards

- Enforce `cargo fmt --check` in CI.
- Enforce `cargo clippy --workspace --all-targets --all-features` in CI.
- Enforce `cargo test --workspace` in CI.
- Enforce frontend install, build, lint, and test steps in CI once the UI scaffold exists.
- Run platform-specific helper tests in a matrix job when those helpers are introduced.

## Tauri Standards

- Expose only the minimum command surface required by the UI.
- Use capability files to scope command and plugin access per window.
- Do not expose raw shell or filesystem power to the frontend unless a feature explicitly requires it and has been reviewed.
- Long-running work must not block the UI thread.
- Emit typed, documented events for background task progress.

## Frontend Standards

### Svelte

- Use Svelte components for presentation and interaction, not core business rules.
- Keep components focused on one feature or view concern.
- Extract reusable state and view helpers into `src/lib`.
- Prefer composition over large monolithic components.

### JavaScript and TypeScript

- Simple presentational components may use plain JavaScript.
- Shared models, Tauri command contracts, and non-trivial state modules should use TypeScript.
- Avoid advanced type tricks that reduce readability.

### State Management

- Prefer local component state first.
- Use Svelte stores only for shared UI state or app-wide reactive state.
- Treat Rust-backed state as authoritative for domain data.
- Cache frontend copies deliberately and invalidate them explicitly.

### Styling

- Use a small design-token layer for colors, spacing, radius, typography, and shadows.
- Avoid heavyweight UI frameworks unless they solve a real problem the native design system cannot.
- Preserve accessibility and keyboard usability in every new screen.

## Domain Blocking Standards

- Domain blocking code must separate policy compilation from policy enforcement.
- The app should reason in normalized domains and domain groups, not raw user input strings only.
- All enforcement actions must be auditable.
- Emergency unlock behavior must be explicit and logged.
- Enforcement adapters must degrade safely and report failure clearly.

## Domain Monitoring Standards

- Monitoring must be opt-in where platform behavior or regulation requires it.
- Store raw access events separately from derived analytics.
- Never label heuristic estimates as exact time spent.
- Keep monitoring data user-visible and deletable.
- Avoid collecting data that is not necessary for focus features.

## Sync Standards

- Sync is optional and must not block local usage.
- Every outbound sync action should be retryable and as idempotent as practical.
- Persist provider mappings explicitly.
- Surface conflicts rather than hiding them.
- Keep provider-specific fields out of the generic task model unless there is a clear cross-provider reason.

## Security Standards

- Store secrets in Stronghold or an equivalent secure storage mechanism.
- Never log tokens, authorization headers, or raw sensitive payloads.
- Review all new Tauri commands for privilege boundaries.
- Validate all inputs crossing the UI to backend boundary.
- Restrict helper communication to the smallest command set possible.

## Platform Helper Standards

- Privileged helper code must have its own tests and explicit protocol contracts.
- The helper must authenticate or verify control messages from the main app.
- The helper must fail in a documented way and expose status codes.
- Minimize helper privileges and startup scope.
- Keep helper update compatibility documented and tested.
- Prefer Unix domain sockets on Unix-like systems and named pipes on Windows over a local HTTP server for privileged control paths.

## Testing Standards

### Backend

- Unit test domain services thoroughly.
- Integration test repositories with a temporary SQLite database.
- Integration test sync planning and conflict handling.
- Add regression tests for timer state transitions and policy compilation bugs.

### Frontend

- Component test screens and shared UI state.
- Test command boundaries with mocks or fixtures.
- Use end-to-end tests for essential user journeys.

### Platform and Helper

- Contract test helper IPC.
- Test enforcement state transitions on supported target operating systems.
- Keep manual verification checklists for OS-level features that are difficult to automate.

## Logging and Observability Standards

- Use structured logs in backend and helper code.
- Separate user activity history from developer diagnostics.
- Include correlation ids or operation ids for sync runs and helper commands.
- Keep log volume bounded for high-frequency monitoring events.

## Git and Review Standards

- Make small, reviewable commits.
- Keep unrelated refactors out of feature changes.
- Add tests with behavior changes unless impossible or clearly documented.
- Reviews should prioritize correctness, regressions, security boundaries, and data integrity.

## Definition of Done

A change is done when:

- Code follows layer boundaries.
- Tests cover the important behavior.
- Docs are updated when the behavior or architecture changed.
- Security and privacy implications are reviewed.
- The change can be understood by someone new to the project without guessing missing context.
