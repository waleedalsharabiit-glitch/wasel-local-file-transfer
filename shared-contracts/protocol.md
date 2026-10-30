# Wasel Local API Contract — Draft

Status: draft only. These endpoints are proposed and are not implemented yet.

## General rules

- All endpoints are available only while the user starts the receiving service.
- Requests must be authorized using the active pairing session.
- The server must validate the request origin, authorization, input size, and path.
- Do not accept arbitrary filesystem paths from a peer.

## Proposed endpoints

### GET /api/v1/status
Returns service status, protocol version, and available capabilities.

### POST /api/v1/pairing/request
Requests pairing. Requires a valid, unexpired pairing code.

### POST /api/v1/pairing/approve
Approves or rejects a pending pairing request. Approval must be user-controlled.

### GET /api/v1/files
Lists only files and folders the user has explicitly granted access to.

### POST /api/v1/transfers
Creates a transfer request and returns a transfer identifier.

### PUT /api/v1/transfers/{transferId}/content
Streams file bytes or a bounded chunk. Requires transfer authorization.

### GET /api/v1/transfers/{transferId}
Returns transfer status and resumable offset when supported.

### DELETE /api/v1/transfers/{transferId}
Cancels a transfer when permitted.

### WebSocket /api/v1/events
Publishes authorized transfer progress and connection events.

## Required future fields

- Protocol version.
- Transfer identifier.
- File size and chunk metadata.
- Resume offset.
- Expected SHA-256.
- Transfer state and error code.

The final schema must be versioned and tested before implementation.
