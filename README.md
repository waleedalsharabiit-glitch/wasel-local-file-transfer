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

Phase 02 (design system and interfaces) is complete. Flutter analysis reports no issues, and the debug APK builds successfully. Project status is tracked in [`docs/roadmap.md`](docs/roadmap.md). The phone app currently runs a local HTTP transfer server with streaming uploads and SHA-256 checks. The desktop browser UI now connects to the phone session to upload files and list, download, or delete phone files.

The desktop UI build succeeds. This does not mean the remaining transfer-engine work is complete: cancellation, resumable large-file transfers, persistent job history, pairing approval, and real-device Wi-Fi/hotspot verification are still outstanding. The phone app's embedded browser page also remains available when opening its session URL directly.

For the development desktop UI, run `npm install` and `npm run dev` inside `desktop-web/`. Keep the computer and phone on the same local Wi-Fi network or connect the computer to the phone's hotspot. Start a receiving session in the Wasel phone app, then enter the session address and access code in the desktop UI.
