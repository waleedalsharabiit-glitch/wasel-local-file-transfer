# Wasel Test Plan

## Environment
- [ ] Flutter doctor Android toolchain has no blocking errors.
- [ ] Flutter can build a debug APK.
- [ ] Flutter analyzer reports no errors.
- [ ] Browser project installs dependencies and builds successfully.

## Transfer engine
- [ ] Small file in each direction.
- [ ] Large file without loading the complete file into memory.
- [ ] Interrupted transfer and resume.
- [ ] SHA-256 matches at source and destination.
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
