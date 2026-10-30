# Wasel — واصل

Wasel is a local-network file transfer application.

## Applications

- mobile/: Flutter and Dart Android application.
- desktop-web/: React and TypeScript browser interface for computers.
- shared-contracts/: shared API and protocol contracts.
- docs/: architecture, security, testing, and user documentation.
- scripts/: development and verification scripts.
- backups/: project-specific backups when needed.

## Core principles

- Local Wi-Fi or phone hotspot; no cloud server required for local transfers.
- No mandatory account.
- Pairing and explicit approval before accepting transfers.
- Stream large files instead of loading entire files into memory.
- Verify completed transfers using SHA-256.
- Support bidirectional transfers and resumable transfers where implemented.
- The computer uses a browser, not a required Windows application.
- Do not mark features complete until they are implemented and tested.

## Current status

Phase 1: project foundation and environment validation.

The transfer engine and user interfaces are not yet implemented.
