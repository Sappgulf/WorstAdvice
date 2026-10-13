#!/usr/bin/env python3
"""Check local configuration consistency; this does not certify a deployed schema."""
from pathlib import Path
import plistlib
import re
import sys

root = Path(__file__).resolve().parent.parent
errors = []

def require(condition, message):
    if not condition:
        errors.append(message)

schema = (root / 'Badvice/CloudKit/CloudKitSchema.swift').read_text()
project = (root / 'Badvice.xcodeproj/project.pbxproj').read_text()
entitlements = plistlib.loads((root / 'Badvice/Badvice.entitlements').read_bytes())
privacy = plistlib.loads((root / 'Badvice/Resources/PrivacyInfo.xcprivacy').read_bytes())
match = re.search(r'static let containerIdentifier = "([^"]+)"', schema)
require(match is not None, 'CloudKit container identifier is missing from schema config.')
if match:
    require(entitlements.get('com.apple.developer.icloud-container-identifiers') == [match[1]], 'Entitlements and CloudKit config must use the same container.')
require('CloudKit' in entitlements.get('com.apple.developer.icloud-services', []), 'CloudKit entitlement is missing.')
require(project.count('CODE_SIGN_ENTITLEMENTS = Badvice/Badvice.entitlements;') == 2, 'Debug and Release must both attach the app entitlements.')
info = plistlib.loads((root / 'Badvice/Info.plist').read_bytes())
require(project.count('INFOPLIST_FILE = Badvice/Info.plist;') == 2, 'Debug and Release must include the app Info.plist.')
require(info.get('BadviceCloudKitSigningAllowed') == '$(CODE_SIGNING_ALLOWED)', 'CloudKit availability must reflect build signing.')
require(any('badvice' in item.get('CFBundleURLSchemes', []) for item in info.get('CFBundleURLTypes', [])), 'Register the widget and app-intent badvice URL scheme.')
require(privacy.get('NSPrivacyTracking') is False, 'Badvice must not enable tracking.')
required = {'NSPrivacyCollectedDataTypeName', 'NSPrivacyCollectedDataTypeUserID', 'NSPrivacyCollectedDataTypeOtherUserContent'}
collected = {entry['NSPrivacyCollectedDataType']: entry for entry in privacy.get('NSPrivacyCollectedDataTypes', [])}
require(required <= collected.keys(), 'The manifest must disclose optional CloudKit profiles and user content.')
for name in required & collected.keys():
    entry = collected[name]
    require(entry.get('NSPrivacyCollectedDataTypeTracking') is False, f'{name} must not be used for tracking.')
    require(entry.get('NSPrivacyCollectedDataTypeLinked') is True, f'{name} is associated with a social profile.')
    require('NSPrivacyCollectedDataTypePurposeAppFunctionality' in entry.get('NSPrivacyCollectedDataTypePurposes', []), f'{name} needs its actual app-functionality purpose.')
if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print('Developer configuration check passed: container, entitlements, signing, URL scheme, and privacy declarations agree.')
