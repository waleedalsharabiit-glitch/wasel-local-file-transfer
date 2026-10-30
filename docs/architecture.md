# Wasel Architecture

## Target architecture

1. Android application: Flutter/Dart.
2. Computer interface: React/TypeScript in a modern browser.
3. Local control API: HTTP REST endpoints.
4. Progress and live events: WebSocket.
5. File transfer: streamed binary data, with chunk support for resumable transfers.
6. Discovery: mDNS/NSD where supported; provide a manual local-address fallback.
7. Integrity: SHA-256 verification after transfer.
8. Persistence: local metadata and transfer history.
9. No cloud service is required for the local-network use case.

## Network lifecycle

1. User starts the receiving service on Android.
2. The application shows its local network address and pairing information.
3. The computer opens the supplied address in a browser.
4. The user verifies and approves the pairing.
5. Transfer requests are authenticated and approved.
6. Files are streamed, verified, and recorded.

## Design constraints

- Network discovery must not be the only connection method.
- Browser permissions and browser security limitations must be respected.
- Avoid loading full files into RAM.
- Large-file transfers must handle interrupted connections.
- A browser page cannot guarantee background transfer after it is closed.
- Android background operation is subject to operating-system restrictions.
- HTTP on a local network does not encrypt traffic by itself.

This document describes the target design, not completed functionality.
