# Wasel Security Requirements

- Pairing must require user consent.
- Use short-lived pairing codes or tokens.
- Do not expose a receiving service to every network interface without an explicit policy.
- Restrict accepted origins and validate requests to mitigate CSRF and unauthorized browser access.
- Validate every requested path and prevent path traversal.
- Never trust a filename, MIME type, file size, or path supplied by a remote peer.
- Restrict access to explicitly selected files and folders.
- Use bounded streaming and chunk sizes.
- Verify file integrity using SHA-256.
- Protect trusted-device credentials and revoke them when requested.
- Do not describe local HTTP as encrypted.
- Explain that other devices on the same network may be able to observe unencrypted traffic.
- Do not implement automatic acceptance of unknown peers.
- Treat clipboard sharing and chat messages as user-approved operations.

Security features must be implemented and tested before production release.
