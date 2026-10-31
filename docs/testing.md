# Wasel Test Plan

## Environment
- [ ] Flutter doctor Android toolchain has no blocking errors.
- [ ] Flutter can build a debug APK.
- [ ] Flutter analyzer reports no errors.
- [ ] Browser project installs dependencies and builds successfully.

## Transfer engine
- [x] Resumable 4 MiB chunk upload over loopback HTTP; final SHA-256 is returned and checked.
- [x] Byte-range download over loopback HTTP.
- [x] Native-download ticket remains limited to the named file.
- [x] Interrupted upload resumes at the server-reported offset, including after server restart.
- [x] Invalid offset rejection, transfer cancellation, and two independent concurrent transfers.
- [ ] Small file in each direction on a physical phone and computer.
- [ ] Large file without loading the complete file into memory on physical devices.
- [ ] Abrupt real network interruption and resume on Wi-Fi and hotspot.
- [ ] Independently hash source and downloaded destination on physical devices.
- [ ] Duplicate filenames and conflict resolution.
- [ ] Insufficient storage and permission-denied handling.
- [ ] Invalid paths and path traversal attempts.

## Network and security
- [ ] Same Wi-Fi.
- [ ] Phone hotspot.
- [ ] Network address changes.
- [ ] Unauthorized pairing rejection.
- [ ] Expired pairing token rejection.
- [ ] Browser-origin and CSRF protection.
- [ ] Receiving service stops when the user stops it.

## Release
- [ ] Test on a physical Android device.
- [ ] Test on a second device and computer.
- [ ] Test large files and long-running transfers.
- [ ] Document Android background restrictions.
- [ ] Verify final APK installation.
