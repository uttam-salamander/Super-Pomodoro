# Product Requirements Document

## Document Control

- Product: Super Pomodoro
- Version: 0.2
- Status: Draft
- Owner: Product and Engineering
- Last updated: 2026-03-13

## Product Vision

Super Pomodoro helps users protect deep work by combining a timer, tasks, sync, and system-level domain control in one local-first desktop application. The product should feel lightweight, predictable, private, and hard to bypass during an active focus session without turning into surveillance software or enterprise device management.

## Problem Statement

Most focus tools solve only one slice of the problem:

- Timer tools do not connect sessions to real work.
- Task tools do not protect the user from distractions.
- Website blockers are often browser-specific and easy to disable.
- Calendar and task systems become fragmented across local apps, GitHub, Google, and other tools.
- Users lack a single trustworthy view of what they planned, what they completed, and what distracted them.

Super Pomodoro addresses those gaps by treating focus as a system, not a timer widget.

## Goals

- Provide a reliable Pomodoro workflow with task linkage and session history.
- Support lightweight task management for personal work.
- Block distracting domains system-wide across major browsers on desktop.
- Monitor domain access at the system level and estimate time spent on distracting domains.
- Sync task and schedule data with GitHub and Google Calendar.
- Remain local-first, fast, and privacy-conscious.
- Share as much logic as possible across platforms while accepting that enforcement will remain platform-specific.

## Non-Goals

- Building a team collaboration platform in v1.
- Guaranteeing unbreakable anti-tamper enforcement against an admin or root user.
- Supporting every sync provider in the first release.
- Performing full URL content inspection for all encrypted traffic.
- Acting as an enterprise mobile device management product.
- Replacing full-featured project management tools.

## Product Principles

- Local-first: The local device is the source of truth.
- Focus-first: Session flow must stay simple and fast.
- Honest enforcement: The app should be difficult to bypass during normal use, but the product must not overpromise absolute lock-down.
- Privacy by default: Data stays local unless the user explicitly enables sync.
- Clear boundaries: Shared product behavior lives in Rust core logic; OS-specific enforcement lives in adapters and helpers.

## Personas

### Solo Builder

- Works independently on side projects or freelancing.
- Needs lightweight task planning and strong distraction control.
- Wants GitHub visibility for work items and progress.

### Student or Researcher

- Plans study blocks and wants a visible history of completed sessions.
- Needs browser-agnostic blocking rather than a single-browser extension.
- Values analytics more than external task sync.

### Knowledge Worker

- Uses Google Calendar for scheduling and GitHub or another system for task context.
- Wants the app to fit into existing workflows without becoming another complicated system.

## User Problems to Solve

- "I start a focus session and still end up on distracting websites."
- "My tasks, my timer, and my calendar all live in different places."
- "I can see that I was distracted, but not where my time actually went."
- "I want blocking that works across browsers."
- "I want analytics that are useful without feeling invasive."

## Release Strategy

### Phase 1: Desktop Core

- Pomodoro timer
- Tasks
- Local persistence
- Notifications
- Session history
- Local analytics

### Phase 2: Sync Foundations

- GitHub sync
- Google Calendar sync
- Account linking
- Sync queue and conflict handling

### Phase 3: Domain Blocking and Monitoring

- System-level domain blocking
- Domain group management
- Block schedules tied to sessions
- Access logging and estimated time spent

### Phase 4: Mobile Companion

- Shared task and session model
- Read/write sync
- Focus workflow without full parity for blocking

## Functional Requirements

### Timer and Session Management

- Users must be able to start, pause, resume, skip, and complete focus sessions.
- Users must be able to configure focus length, short break length, long break length, and long break cadence.
- Users must be able to choose a named focus mode that combines timer defaults and blocking behavior.
- Users must be able to attach a session to a task.
- The app must persist session state and recover gracefully after restart.
- If a user pauses a session and closes the app, reopening the app must restore that session in the paused state with the same remaining time.
- The app must record completed, cancelled, interrupted, and abandoned sessions.
- Interrupted and abandoned sessions must be distinguishable in analytics and history.
- The app should support notifications at phase boundaries.

### Task Management

- Users must be able to create, update, reorder, complete, archive, and delete tasks.
- Tasks should support title, notes, status, due date, estimate, tags, and optional project grouping.
- Users should be able to view tasks by inbox, today, upcoming, completed, and archived states.
- A task should show linked session count, last worked time, and total focus duration.
- Completed tasks must remain visible in history and analytics.

### Domain Blocking

- Users must be able to define blocked domain groups.
- Domain groups must support explicit domains and wildcard subdomain patterns.
- Users must be able to attach domain groups to focus sessions, focus modes, or schedules.
- When blocking is active, the app must deny normal access to blocked domains across major browsers on desktop.
- The app should support an emergency unlock flow with explicit user action and audit logging.
- The app should support allowlists for domains required by the app itself or by explicitly approved workflows.

### Domain Monitoring

- The app must record domain access events when monitoring is enabled.
- Each event should capture domain, timestamp, action, source process when available, and policy context.
- The app should compute estimated active time for domains using network events plus local activity heuristics.
- The app must clearly label estimated time as estimated rather than exact.
- Users must be able to disable monitoring independently from blocking where platform support permits.

### Sync

- Users must be able to enable sync providers individually.
- GitHub sync must support mapping local tasks to GitHub issues.
- Google Calendar sync must support mapping planned focus blocks and deadlines to calendar events.
- The app must queue sync operations for retry when offline.
- The app must detect and surface sync conflicts rather than silently overwriting data.
- Sync must remain optional and disabled by default.

### Analytics and Reporting

- Users must be able to view completed sessions over time.
- Users must be able to view task completion trends.
- Users must be able to view blocked attempt counts by day and by domain group.
- Users should be able to view estimated distracting-domain time over time.
- Users should be able to export personal data and reports.

### Settings and Accounts

- Users must be able to configure app behavior, focus defaults, notifications, and sync providers.
- Users must be able to review stored accounts and revoke tokens.
- Users must be able to review blocking and monitoring permissions.

## Non-Functional Requirements

### Performance

- Starting a focus session should feel instantaneous.
- Local task and session views should load within 200 ms on typical datasets.
- Background monitoring and blocking must avoid noticeable system slowdown.

### Reliability

- Local data must survive app restarts and power loss within the limits of SQLite durability.
- Blocking should fail predictably and log failures.
- Sync retries must use backoff and idempotent operations where possible.

### Privacy and Security

- User data must remain local unless sync is explicitly enabled.
- Access tokens must be stored securely.
- Monitoring data must be visible to the user and easy to delete.
- The product must never claim exact browsing time when only heuristics are available.

### Accessibility

- Keyboard navigation must be supported for core flows.
- Timer state must be visually obvious and screen-reader friendly.
- High-contrast themes must be supported.

### Portability

- The desktop product must support macOS and Windows first.
- Linux support should follow with a clearly documented enforcement model.
- Mobile should reuse data and sync models even if blocker behavior differs.

## MVP Scope

The MVP is the smallest release that proves the product value without pretending to solve every enforcement problem.

Included:

- Desktop timer and tasks
- Local persistence
- Session history
- GitHub sync
- Google Calendar sync
- Domain group management
- System-level domain blocking on primary desktop targets
- Domain access logging
- Estimated focus and distraction analytics

Excluded:

- Team features
- Full mobile blocker parity
- Full URL path monitoring
- Browser extensions
- AI planning features

## Success Metrics

- Daily active focus sessions per user
- Weekly session completion rate
- Weekly task completion rate
- Number of blocked attempts during focus sessions
- Estimated distracting-domain time reduction over four weeks
- Sync reliability rate
- Crash-free session completion rate

## Risks

- Domain blocking is highly platform-specific and can require elevated privileges or OS entitlements.
- Monitoring domain access may create trust concerns if messaging is vague or intrusive.
- Mapping services to domains can become complex for large consumer sites.
- Sync conflicts and duplicate mappings can undermine trust if not handled visibly.
- Packaging a privileged helper can complicate installation and updates.

## Open Questions

- Which platform should ship first for domain blocking: macOS or Windows?
- Should estimated distracting time depend only on domain access events, or also on active-window heuristics?
- Should the first GitHub integration support only issues, or also repository-backed task storage later?
- Which emergency unlock policy best fits the product: hard confirmation, timed unlock, or session cancellation?

## Session Outcome Definitions

- `Completed`: The phase reached its intended end.
- `Cancelled`: The user explicitly ended the session early.
- `Interrupted`: The session ended early because of an external condition such as app failure, helper failure, reboot, or a strict-enforcement error.
- `Abandoned`: A paused or interrupted session was never resumed and expired past the recovery window.

## Acceptance Criteria for Initial Project Setup

- Product scope is documented and agreed.
- Technical boundaries are documented.
- Diagrams explain major flows clearly.
- Coding standards define how implementation should proceed.
- The team can start scaffolding without guessing the core product shape.
