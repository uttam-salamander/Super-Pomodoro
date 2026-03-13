# System Diagrams

The diagrams in this document are intended to make the project understandable before implementation begins. They focus on system boundaries, data flow, sync behavior, and the interaction between the app and system-level domain enforcement.

## 1. System Context

```mermaid
flowchart LR
    user["User"] --> app["Super Pomodoro App"]
    app --> localdb["Local SQLite Database"]
    app --> secrets["Secure Credential Store"]
    app --> helper["Privileged Platform Helper"]
    app --> gh["GitHub"]
    app --> gcal["Google Calendar"]
    helper --> os["Operating System Network Controls"]
    helper --> net["Network Traffic and Domain Events"]
    app --> reports["Local Analytics and Reports"]
```

## 2. High-Level Component Architecture

```mermaid
flowchart TB
    subgraph ui["Frontend"]
        svelte["Svelte UI"]
        state["View State"]
    end

    subgraph tauri["Tauri App"]
        commands["Tauri Commands"]
        events["App Events"]
    end

    subgraph core["Rust Core"]
        timer["Timer Engine"]
        tasks["Task Engine"]
        blocking["Blocking Engine"]
        monitoring["Monitoring Engine"]
        sync["Sync Engine"]
    end

    subgraph infra["Infrastructure"]
        sqlite["SQLite"]
        stronghold["Stronghold"]
        oauth["OAuth Flows"]
        http["HTTP Clients"]
    end

    subgraph platform["Platform Enforcement"]
        helper["Privileged Helper"]
        adapter["OS Adapter"]
    end

    svelte --> commands
    state --> commands
    commands --> timer
    commands --> tasks
    commands --> blocking
    commands --> monitoring
    commands --> sync
    timer --> sqlite
    tasks --> sqlite
    monitoring --> sqlite
    sync --> sqlite
    sync --> stronghold
    sync --> oauth
    sync --> http
    blocking --> helper
    monitoring --> helper
    helper --> adapter
    core --> events
    events --> svelte
```

## 3. Repository and Runtime Boundaries

```mermaid
flowchart LR
    subgraph repo["Repository"]
        docs["docs/"]
        web["src/"]
        rust["src-tauri/"]
    end

    subgraph runtime["Runtime"]
        webview["Webview UI"]
        appcore["Rust App Core"]
        helper["Privileged Helper"]
    end

    docs --> web
    docs --> rust
    web --> webview
    rust --> appcore
    appcore --> helper
```

## 4. Domain Model

```mermaid
erDiagram
    PROJECT ||--o{ TASK : "contains"
    TASK ||--o{ SESSION : "is worked in"
    TASK ||--o{ FOCUS_PLAN : "is planned in"
    TASK ||--o{ SYNC_MAPPING : "maps to remote objects"
    TASK ||--o{ TASK_TAG : "has"
    TAG ||--o{ TASK_TAG : "labels"
    FOCUS_MODE ||--o{ SESSION : "drives"
    FOCUS_MODE ||--o{ FOCUS_PLAN : "defaults"
    FOCUS_MODE ||--o{ BLOCKING_POLICY : "configures"
    FOCUS_PLAN ||--o{ SESSION : "creates"
    SESSION ||--o{ SESSION_EVENT : "emits"
    DOMAIN_GROUP ||--o{ DOMAIN_RULE : "contains"
    BLOCKING_POLICY ||--o{ BLOCKING_POLICY_DOMAIN_GROUP : "assigns"
    DOMAIN_GROUP ||--o{ BLOCKING_POLICY_DOMAIN_GROUP : "is referenced by"
    BLOCKING_POLICY ||--o{ BLOCKING_STATE : "produces"
    DOMAIN_ACCESS_EVENT }o--|| BLOCKING_POLICY : "evaluated against"
    DOMAIN_ACCESS_EVENT }o--|| SESSION : "may occur during"
    DOMAIN_ACCESS_EVENT ||--o{ DOMAIN_AGGREGATE_DAILY : "rolls up into"
    PROVIDER_ACCOUNT ||--o{ SYNC_MAPPING : "owns"
    FOCUS_PLAN ||--o{ SYNC_MAPPING : "maps to remote objects"
    PROVIDER_ACCOUNT ||--o{ SYNC_OPERATION : "executes"
    SYNC_OPERATION ||--o{ SYNC_CONFLICT : "may create"
```

## 5. Focus Session and Blocking Flow

```mermaid
sequenceDiagram
    participant User
    participant UI as Svelte UI
    participant App as Tauri App
    participant Core as Rust Core
    participant Helper as Platform Helper
    participant OS as OS Network Controls

    User->>UI: Start focus session
    UI->>App: invoke start_session(task_id, mode)
    App->>Core: create session and resolve policy
    Core->>Helper: apply blocking policy
    Helper->>OS: enable domain rules
    OS-->>Helper: enforcement status
    Helper-->>Core: applied policy result
    Core-->>App: session_started + policy_status
    App-->>UI: emit timer and blocking state
```

## 6. Session State Machine

```mermaid
stateDiagram-v2
    [*] --> Planned
    Planned --> Running: start
    Running --> Paused: pause
    Paused --> Running: resume
    Running --> Completed: timer elapsed
    Running --> Cancelled: user stop
    Paused --> Cancelled: user stop
    Running --> Interrupted: external failure
    Interrupted --> Running: recover
    Interrupted --> Abandoned: recovery window expires
    Paused --> Abandoned: recovery window expires
    Completed --> [*]
    Cancelled --> [*]
    Abandoned --> [*]
```

## 7. Domain Monitoring Flow

```mermaid
sequenceDiagram
    participant Browser as Browser or App
    participant OS as OS Network Stack
    participant Helper as Platform Helper
    participant Core as Monitoring Engine
    participant DB as SQLite
    participant UI as Analytics UI

    Browser->>OS: Request domain access
    OS->>Helper: expose connection or DNS event
    Helper->>Core: normalized domain access event
    Core->>DB: persist raw event
    Core->>DB: update rollups and estimates
    UI->>Core: request analytics
    Core->>DB: fetch aggregates
    Core-->>UI: visits, blocked attempts, estimated time
```

## 8. Sync Flow

```mermaid
sequenceDiagram
    participant User
    participant UI as Svelte UI
    participant Core as Rust Core
    participant DB as SQLite
    participant Queue as Sync Queue
    participant GH as GitHub
    participant GC as Google Calendar

    User->>UI: Complete task or schedule focus block
    UI->>Core: invoke mutation
    Core->>DB: save local change
    Core->>Queue: enqueue sync operations
    Queue->>GH: push task changes
    Queue->>GC: push schedule changes
    GH-->>Queue: remote ids and timestamps
    GC-->>Queue: remote ids and timestamps
    Queue->>DB: update mappings and queue state
```

## 9. Time Estimation Pipeline

```mermaid
flowchart LR
    access["Raw Domain Access Events"] --> normalize["Normalize Domains"]
    normalize --> correlate["Correlate with Session State"]
    correlate --> activity["Apply Active Window and Idle Heuristics"]
    activity --> aggregate["Compute Estimated Time"]
    aggregate --> analytics["Analytics Views and Reports"]
```

## 10. Helper IPC

```mermaid
sequenceDiagram
    participant App as Main Tauri App
    participant Transport as UDS or Named Pipe
    participant Helper as Privileged Helper

    App->>Transport: connect
    Transport->>Helper: open local channel
    App->>Helper: handshake(version, auth, capabilities)
    Helper-->>App: ack(status, protocol_version)
    App->>Helper: apply_policy(policy_revision, rules)
    Helper-->>App: applied(status, revision)
    Helper-->>App: event_stream(heartbeat, access_event, error)
    App->>Helper: query_status or flush_spool
```

## 11. Deployment Architecture

```mermaid
flowchart TB
    subgraph desktop["Desktop Installation"]
        main["Main Tauri App"]
        helper["Privileged Helper"]
        store["Local Database and Secure Store"]
    end

    subgraph external["External Providers"]
        gh["GitHub API"]
        gc["Google Calendar API"]
    end

    subgraph platform["OS Services"]
        net["Network Controls"]
        notify["Notifications"]
        startup["Autostart"]
    end

    main --> store
    main --> gh
    main --> gc
    main --> notify
    main --> startup
    main --> helper
    helper --> net
```

## 12. Responsibility Split

```mermaid
flowchart LR
    ui["UI Layer"] -->|"owns"| views["Views and Interaction"]
    app["Application Layer"] -->|"owns"| orchestration["Commands and Events"]
    core["Domain Layer"] -->|"owns"| business["Timer, Tasks, Sync, Policies"]
    infra["Infrastructure Layer"] -->|"owns"| persistence["DB, HTTP, Secrets"]
    platform["Platform Layer"] -->|"owns"| enforcement["Blocking and Monitoring Enforcement"]
```
