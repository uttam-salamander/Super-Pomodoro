# Documentation Index

This folder contains the planning and engineering documents for Super Pomodoro.

## Documents

- [Product Requirements Document](./PRD.md)
- [Technical Architecture](./ARCHITECTURE.md)
- [Database Schema](./DATABASE_SCHEMA.md)
- [System Diagrams](./DIAGRAMS.md)
- [Coding Standards](./CODING_STANDARDS.md)

## Reading Order

1. Read the PRD to understand scope, user value, and release boundaries.
2. Read the architecture document to understand system structure and technical decisions.
3. Read the database schema to understand durable state, retention, and recovery semantics.
4. Read the diagrams to understand runtime boundaries and major flows.
5. Read the coding standards before starting implementation.

## Current Focus

The project is currently defined as:

- Desktop-first
- Tauri + Rust + Svelte
- Local-first data model
- GitHub and Google Calendar sync
- System-level domain blocking and monitoring on desktop
