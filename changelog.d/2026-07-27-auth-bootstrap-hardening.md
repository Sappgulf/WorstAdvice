# Auth and bootstrap hardening

## Reliability and performance
- Prepare Application Support before opening the SwiftData store to avoid first-launch recovery work
- Ignore the local XcodeBuildMCP derived-data directory

## Account experience
- Keep fresh display-name drafts empty instead of copying the device name
- Add live password requirement feedback and keyboard-first field progression
- Keep account creation disabled while a non-empty display name is invalid

## Accessibility
- Attach Settings destination identifiers to their interactive navigation links
