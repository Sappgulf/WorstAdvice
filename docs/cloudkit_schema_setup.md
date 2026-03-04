# CloudKit Friends Schema Setup

This app's Friends feature expects the `iCloud.com.worstadvice.app` container and stores social data in the Public database.

## Confirm The Container

1. Open the `Badvice` app target in Xcode.
2. Open `Signing & Capabilities`.
3. Confirm `iCloud` is enabled.
4. Confirm the CloudKit container list includes `iCloud.com.worstadvice.app`.
5. Confirm the app target uses [`Badvice/Badvice.entitlements`](/Users/austinbeatty/Downloads/Badvice/Badvice/Badvice.entitlements).

## Public Database Record Types

Create these record types in the Public database. The names must match the constants in [`CloudKitSchema.swift`](/Users/austinbeatty/Downloads/Badvice/Badvice/CloudKit/CloudKitSchema.swift).

### `UserProfile`

Fields:

- `handle`: `String`
  Mark `Queryable`.
- `displayName`: `String`
- `createdAt`: `Date/Time`
- `ownerUserRecordName`: `String`
  Mark `Queryable`.
- `avatarAsset`: `Asset`
  Optional.

Notes:

- The app uses `recordName = normalized handle`.
- Handle normalization lowercases input, strips `@`, trims whitespace, and keeps only `a-z`, `0-9`, `.`, and `_`.

### `FriendRequest`

Fields:

- `fromUser`: `Reference` to `UserProfile`
  Mark `Queryable`.
- `toUser`: `Reference` to `UserProfile`
  Mark `Queryable`.
- `status`: `String`
  Mark `Queryable`.
- `createdAt`: `Date/Time`

Expected app values:

- `pending`
- `accepted`
- `rejected`
- `canceled`

The current app may also write `blocked` for the existing block flow.

### `FriendEdge`

Fields:

- `fromUser`: `Reference` to `UserProfile`
  Mark `Queryable`.
- `toUser`: `Reference` to `UserProfile`
- `createdAt`: `Date/Time`

## Recommended Indexes

- `FriendRequest`
  Add query support for `toUser + status`.
- `FriendRequest`
  Add query support for `fromUser + status`.
- `FriendEdge`
  Add query support for `fromUser`.
- `UserProfile`
  Add query support for `handle`.

If the dashboard UI asks for sort support, add it on `createdAt` for `FriendRequest` and `FriendEdge`.

## Development To Production

1. Run the app from Xcode while signed into iCloud on a real device.
2. In the app menu, use `CloudKit -> Bootstrap Dev Schema`.
3. Open CloudKit Dashboard for `iCloud.com.worstadvice.app`.
4. Verify the Development environment now contains `UserProfile`, `FriendRequest`, and `FriendEdge`.
5. Verify the fields above exist with the exact names and types.
6. Deploy the Development schema to Production before TestFlight or App Store builds.

## Common Pitfalls

- Wrong environment:
  Xcode debug builds use Development schema. TestFlight and App Store builds use Production schema.
- Wrong container:
  The app expects `iCloud.com.worstadvice.app`.
- Not signed into iCloud:
  `CKCurrentUserDefaultName` and public writes will fail if the device is not signed in.
- Record type mismatch:
  `UserProfile` is required. `User` will not satisfy the new Friends code path.
- Field mismatch:
  `fromUser` and `toUser` are required. Older names like `fromUserRef`, `toUserRef`, `aUserRef`, `bUserRef`, or `since` do not satisfy the new Friends code path.
- Missing queryability:
  `handle`, `FriendRequest.fromUser`, `FriendRequest.toUser`, `FriendRequest.status`, and `FriendEdge.fromUser` must be queryable for Friends to work cleanly.
