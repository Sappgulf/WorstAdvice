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
| `FriendRequest` | `fromUser` Reference, `toUser` Reference, optional `responseTo` Reference to the original request, `status` String, `createdAt`, `updatedAt` | Query `fromUser`, `toUser`, `status`; load participant records before resolving status |
| `FriendEdge` | `fromUser` Reference, `toUser` Reference, `createdAt` | Query `fromUser` |
| `Post` | `authorRef` Reference, `type` String, `text` String, `visibility` String, `createdAt` | Query `authorRef`, `visibility`; sort `createdAt` |
| `ChaosScore` | `seasonId` String, `userRef` Reference, `score` Int64, `updatedAt` | Query `seasonId`; sort `score` |
| `CollabDoc` | `ownerRef` Reference, `contributorsRefs` Reference List, `type` String, `content` String, `version` Int64, `createdAt`, `updatedAt` | Query `ownerRef`, `contributorsRefs`; sort `updatedAt` |
| `ModerationReport` | `clientReportID` String, `targetType` String, `targetRecordName` String, `reporterHandle` String, optional `reason` String, `createdAt` | No query required for app submission |

Friend request statuses: `pending`, `accepted`, `rejected`, `canceled`, `blocked`. Post/document types: `advice`, `quote`. Current feed visibility is `friends`, a **client filtering value**, not a server access policy.

New profiles reserve `userprofile_<normalized handle>` using a conditional create, so concurrent claims cannot both succeed. Existing profiles retain their generated record IDs. Recovery validates the record's server creator against the current iCloud identity; the writable owner field alone is not proof of ownership. Optional missing records resolve to nil; permission, network, and schema failures remain visible errors.

## Production deployment (2026-11-17)

The signed-in Dashboard was used to inspect Development and Production, validate/import [the additive schema](cloudkit-schema.ckdb), inspect its deployment diff, and deploy it. The Dashboard confirmed **Changes Deployed**. Existing fields and permissions were preserved. The deployment adds missing record types, request response fields, and query/sort indexes, including profile-owner recovery.

Public profiles, requests, posts, and scores retain world-readable records and creator-only writes. `friends` is a client filter, not a privacy boundary. `ModerationReport` and `CollabDoc` allow creator reads/writes and authenticated creation without world reads.

Friend acceptance/decline now creates a recipient-owned response referencing the original request. Resolution verifies the original request's server creator against the sender profile, verifies response creators against the recipient profile, and uses server modification dates to resolve responses. Friendship is derived from validated requests/responses; either participant's block overrides it. Legacy edges no longer authorize friendship.

Profile deletion removes the current user's owned shared records before deleting the profile; moderation reports and content saved independently by other people may remain. The app explains this in its policy.

Local policy and mocked UI tests do not establish delivery between two signed iCloud accounts. The signed two-user acceptance checks below remain required. Collaboration methods are dormant and have no exposed creation/editing workflow; participant collaboration would require a separate sharing implementation and verification.

## Development Dashboard audit (2026-10-13)

The signed-in CloudKit Dashboard was inspected in the **Development** environment only. The CLI still has no `cktool` management token, but the browser session allowed a read-only schema and role inspection. Production was not inspected or changed.

At that historical audit, Development contained only `FriendEdge`, `FriendRequest`, `UserProfile`, and legacy `Users`; social record types and the owner recovery index were missing. The November deployment above supersedes that schema status.

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

The recipient-owned response design addresses the previous foreign-record write problem without granting broad authenticated Write. Verify actual delivery, retries, account switching, and cache refresh with **two different iCloud users** against the deployed policy. Private multi-user collaboration needs CKShare or a server enforcing membership; the dormant public-record methods do not provide that contract.

The privacy manifest and published App Store disclosures declare optional social names, user identifiers, contacts/social graph, user content, and gameplay content, linked to a profile and used for app functionality without tracking. See [Apple's manifest guidance](https://developer.apple.com/documentation/technotes/tn3184-adding-data-collection-details-to-your-privacy-manifest).

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
