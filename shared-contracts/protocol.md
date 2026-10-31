# Wasel Local API Contract — v1 transfer endpoints

Status: implemented for local file transfer. Pairing, folder permissions, and event streaming remain future work.

## General rules

- Endpoints are available while the user starts the receiving service.
- Requests use the active session bearer token.
- The server validates origin, authorization, size, and filenames; peers never provide filesystem paths.

## Transfer endpoints

### POST /api/v1/transfers
JSON body: `{ "name": string, "size": integer, "clientId": string }`. Creates a transfer (or returns the existing transfer for that client id). Response includes `transferId`, `chunkSize` (4 MiB), and current `offset`.

### GET /api/v1/transfers/{transferId}
Returns state, authoritative byte `offset`, total `size`, `chunkSize`, and filename. Query this after reconnect or interruption.

### PUT /api/v1/transfers/{transferId}
Appends one bounded binary chunk. `Content-Range` must be `bytes {offset}-{endInclusive}/{total}` and start at the server's current offset. A chunk is at most 4 MiB.

### POST /api/v1/transfers/{transferId}/complete
Verifies byte count, commits the file to the receive directory, and returns its SHA-256 digest.

### DELETE /api/v1/transfers/{transferId}
Cancels and removes a partial transfer. An active chunk must finish or abort before cancellation succeeds.

### GET /api/download?name={name}
Supports a single `Range: bytes=start-end` with `206`, `Content-Range`, and `Accept-Ranges`, enabling bounded-memory downloads.

### POST /api/download-ticket
Authenticated JSON body `{ "name": string }`. Returns a random file-scoped ticket valid for five minutes. The browser may use it for a native attachment download when the browser does not allow direct-to-disk APIs on the local HTTP origin. Tickets cannot authorize any endpoint other than downloading their named file.

## Compatibility and semantics

- Existing `/api/status`, `/api/files`, `/api/download`, `/api/upload`, and file deletion routes remain available to the mobile app and older web clients.
- Browser uploads at most two files concurrently and sends one chunk per file at a time.
- Repeating create with the same `clientId` returns the pending transfer. The browser queries its status and resumes at the server-reported offset.
- Partial data and metadata live in the hidden `.partials` directory and are reloaded after server restart.
- Final SHA-256 is computed on the phone after all bytes arrive.
- Browser downloads use a bounded range writer where supported; otherwise a scoped ticket lets the browser download the streamed attachment directly without buffering the complete file in the web page.
- Device discovery, user-approved pairing, expected source hashes, and live event streaming remain future work.
