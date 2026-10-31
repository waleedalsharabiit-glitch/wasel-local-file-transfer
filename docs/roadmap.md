# Wasel Implementation Roadmap

The project is developed one phase at a time. A phase is complete only after all of its scope has been implemented and its required verification has passed. A passing build alone does not complete a phase.

## 01 — Project analysis and environment

**Complete.** Flutter/Dart, Android project setup, initial desktop interface structure, shared contracts, dependencies, and Android network permissions were prepared.

## 02 — Design system and interfaces

**Complete.** The mobile app now has a consistent Arabic/English and light/dark experience across its six destinations; a searchable, filterable, sortable file library with image and bounded text previews; a transfer overview and current-session activity history; and chat/clipboard screens. Flutter analysis reported no issues, and a debug APK built successfully. Chat delivery and cross-device clipboard synchronization remain later-phase behavior; the phase-02 screens clearly show their current state.

## 03 — File transfer engine

**In progress — implementation substantially complete; physical network verification remains.** The phone server supports bounded 4 MiB resumable uploads, persistent partial-transfer metadata across server restart, authoritative offsets, cancellation, final SHA-256 verification, and byte-range downloads. The browser queues two concurrent uploads, shows per-file progress/speed/ETA, retries and resumes interrupted uploads, and allows cancellation. Chromium/Edge use bounded range reads for direct-to-disk downloads; other browsers use their regular download path. Automated loopback tests cover upload, hash, range download, restart/resume, invalid offsets, cancellation, and concurrent transfers. Remaining: verify both transfer directions on real devices over Wi-Fi and hotspot, and exercise large files and abrupt network loss on those devices.

## 04 — Browser interface on the computer

**In progress.** A React/TypeScript interface is available, and the development build passes. It can connect to the phone's local session, upload files, and manage files stored on the phone. Remaining work includes polished previews, verified drag-and-drop behavior, progress and throughput details, large-file handling, and receiving-folder behavior/documentation.

## 05 — Device discovery and pairing

**Not started.** Implement automatic discovery, QR and short-lived verification codes, approval of new devices, trusted-device management, and IP-change recovery.

## 06 — Advanced file management

**Not started.** Implement categories, search and sorting, multi-select, folders, duplicate/conflict handling, safe ZIP operations, and storage reporting.

## 07 — Messaging and clipboard

**Not started.** Implement user-approved text/link sharing, clipboard sharing, local chat, attachments, and notifications.

## 08 — Sync and background operation

**Not started.** Implement folder selection, hash-based comparison, sync direction and conflict management, interruption recovery, and speed/battery controls.

## 09 — Verification and release

**In progress.** Earlier Flutter analysis and test passes were reported by the project owner; the current desktop-web production build also passes. Remaining work includes real Wi-Fi/hotspot transfer tests, large-file and interruption testing, security and permission review, resource-use checks, final APK build, and the user guide.
