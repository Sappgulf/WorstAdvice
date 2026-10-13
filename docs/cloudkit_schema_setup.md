# CloudKit setup and verification

Badvice's optional social backend uses `iCloud.com.worstadvice.app`, **Public** database. Local SwiftData history, favorites, settings, credentials, and party rounds remain on the device. There is no automatic cross-device sync for those records.

## Local configuration

The app target attaches `Badvice/Badvice.entitlements` in Debug and Release. Both the entitlement and `CloudKitSocialConfig` specify the same container. Run:

```bash
python3 scripts/check_dev_configuration.py
```

This checks repository configuration consistency. It cannot confirm the provisioning profile, deployed schema, indexes, or server security roles. Debug builds normally use Development; distributed builds use Production. Confirm the actual signed entitlement when validating an archive.

## Expected public schema

Record and field names come from `Badvice/CloudKit/CloudKitSchema.swift`. `createdAt` and `updatedAt` are Date/Time. `score` and `version` are Int64. Reference fields target `UserProfile`.

| Record type | Fields | Query/sort indexes used by the app |
|---|---|---|
| `UserProfile` | `handle` String, `displayName` String, `ownerUserRecordName` String, `createdAt` Date/Time; optional `avatarAsset` Asset | Query `handle`, `ownerUserRecordName` |
| `FriendRequest` | `fromUser` Reference, `toUser` Reference, `status` String, `createdAt`, `updatedAt` | Query `fromUser`, `toUser`, `status`; support the direction + status predicates |
| `FriendEdge` | `fromUser` Reference, `toUser` Reference, `createdAt` | Query `fromUser` |
| `Post` | `authorRef` Reference, `type` String, `text` String, `visibility` String, `createdAt` | Query `authorRef`, `visibility`; sort `createdAt` |
| `ChaosScore` | `seasonId` String, `userRef` Reference, `score` Int64, `updatedAt` | Query `seasonId`; sort `score` |
| `CollabDoc` | `ownerRef` Reference, `contributorsRefs` Reference List, `type` String, `content` String, `version` Int64, `createdAt`, `updatedAt` | Query `ownerRef`, `contributorsRefs`; sort `updatedAt` |
| `ModerationReport` | `clientReportID` String, `targetType` String, `targetRecordName` String, `reporterHandle` String, optional `reason` String, `createdAt` | No query required for app submission |

Friend request statuses: `pending`, `accepted`, `rejected`, `canceled`, `blocked`. Post/document types: `advice`, `quote`. Current feed visibility is `friends`, a **client filtering value**, not a server access policy.

Profiles currently use generated record IDs and are looked up by owner and handle. Do not assume recordName equals handle. Optional missing records resolve to nil; permission, network, and schema failures must remain visible errors.

## Development Dashboard audit (2026-10-13)

The signed-in CloudKit Dashboard was inspected in the **Development** environment only. The CLI still has no `cktool` management token, but the browser session allowed a read-only schema and role inspection. Production was not inspected or changed.

Development currently contains only `FriendEdge`, `FriendRequest`, `UserProfile`, and legacy `Users`. The app also uses `Post`, `ChaosScore`, `CollabDoc`, and `ModerationReport`; those record types are missing. Existing query indexes are `FriendEdge.fromUser`, `FriendRequest.fromUser/status/toUser`, and `UserProfile.handle`. `UserProfile.ownerUserRecordName` is not queryable, so profile recovery falls back to a full `UserProfile` scan and needs an index before the scan becomes too large.

The inspected Development roles grant `_world` Read for `FriendEdge`, `FriendRequest`, `UserProfile`, and `Users`; `_icloud` Create for `FriendEdge`, `FriendRequest`, and `UserProfile`; and `_creator` Write for those four types. This matches the app's ability to create a public profile but means a recipient cannot update a request created by someone else. These are Development observations, not verified Production policy. The signed-device probe added to Debug diagnostics checks only the profile create/read/query/delete path; it does not prove the other missing record types or cross-user writes.

Do not resolve this by granting broad authenticated Write. The friend-request accept/decline flow needs a participant-safe record model or a trusted service; collaborative writes need explicit participant authorization. New social record types also need a deliberate schema and role policy before the social features can be called CloudKit-ready.

## Inspect existing schemas without changing them

With a CloudKit management token already configured using Apple's `cktool`, export Development and Production independently:

```bash
xcrun cktool export-schema --team-id YOUR_TEAM_ID --container-id iCloud.com.worstadvice.app --environment development --output-file .build/cloudkit-development.ckdb
xcrun cktool export-schema --team-id YOUR_TEAM_ID --container-id iCloud.com.worstadvice.app --environment production --output-file .build/cloudkit-production.ckdb
```

Never put tokens into source, command history, logs, or this document. The browser Dashboard was used for the Development audit above; the local CLI still has no management token and was not used to import, export, or deploy schema.

To initialize a disposable Development schema, run a signed Debug build on an iCloud-enabled test device with `-cloudkit-bootstrap-on-launch`. That existing debug-only path writes temporary seed records. Inspect the result and indexes in CloudKit Console before deploying the schema to Production. Do not bootstrap production data or reset a live schema.

## Security and release blockers

CloudKit public database permissions are record-type/role based. The Creator role applies to the iCloud user who created a record. A friends filter in SwiftUI cannot provide private access. See [Apple's CloudKit design guidance](https://developer.apple.com/icloud/cloudkit/designing/) and [shared records](https://developer.apple.com/documentation/CloudKit/shared-records).

The current friend acceptance/decline path updates a sender-created `FriendRequest`, and collaboration edits may target another creator's `CollabDoc`. Before release, verify these operations with **two different iCloud users** and the actual role configuration. Creator-only writes can reject them. Granting all authenticated users Write would allow unrelated users to edit records and is not an acceptable fix. Private multi-user sharing requires a participant-owned response design, CKShare, or a server enforcing membership; this audit did not silently change the deployed data model or permissions.

Also verify concurrent profile creation: handle availability is checked before saving a generated record ID, so global handle uniqueness is not an atomic server guarantee. Production policy needs a reservation/server contract before relying on unique handles.

The privacy manifest now declares optional social names, user identifiers, and user content, associated with a profile and used for app functionality without tracking. Review the matching App Store disclosures and privacy policy before distribution. See [Apple's manifest guidance](https://developer.apple.com/documentation/technotes/tn3184-adding-data-collection-details-to-your-privacy-manifest).

## Signed two-user acceptance checks

1. Missing iCloud account: local advice, saved content, daily quotes, and party mode remain usable; diagnostics explain how to connect.
2. Network failure during profile lookup: show a retryable failure; do not erase the linked identity or show new-profile setup.
3. Switch iCloud identity: clear loaded social collections and pending writes belonging to the old identity; resolve the new owner's profile.
4. First request and first score: absent optional records must not fail with `unknownItem` or partial missing-record errors.
5. Request/accept/decline/block across both accounts: confirm server-authorized changes and cache refresh on each side.
6. Repeated share after a lost response: reuse the operation ID and return one post.
7. Offline queue: survive app relaunch under the same local account, retry after reconnection, and never replay under another iCloud identity.
8. Collaboration: a permitted participant can edit, an unrelated user cannot, and conflicting versions produce a recoverable state.

Simulator mock tests cover local contracts and diagnostics. They do not substitute for these server checks.
