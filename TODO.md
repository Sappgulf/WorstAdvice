# Remaining verified-scope work

- Complete CloudKit Development schema work: add the four app record types that are missing and index `UserProfile.ownerUserRecordName`; see the read-only audit in `docs/cloudkit_schema_setup.md`.
- Inspect Production schema and security roles with an authorized management token; Production was not inspected or changed.
- Run the signed, two-user CloudKit acceptance checks in `docs/cloudkit_schema_setup.md`.
- Resolve participant-write authorization for friend responses and collaboration without broad public Write access.
- Establish atomic global handle uniqueness before relying on it in production.
- Review App Store privacy disclosures and policy against the updated manifest.
- Review new simulator screenshot evidence before preparing store assets; do not treat debug captures as a signed release.
