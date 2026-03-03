#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const repoRoot = process.cwd();
const projectPath = path.join(repoRoot, "Badvice.xcodeproj", "project.pbxproj");
const scanRoots = [
  "Badvice",
  "Badvice.xcodeproj",
  "WorstAdviceTests",
  "BadviceUITests",
  "WorstAdviceWidget",
];

function parseObjects(sectionText) {
  const entryRegex = /\b([A-Za-z0-9]+)\b\s+\/\*.*?\*\/ = \{([\s\S]*?)\n\t\t\};/g;
  const objects = new Map();
  for (const match of sectionText.matchAll(entryRegex)) {
    objects.set(match[1], match[2]);
  }
  return objects;
}

function parseFileReferences(sectionText) {
  const entryRegex =
    /^\t\t([A-Za-z0-9]+)\s+\/\*.*?\*\/ = \{isa = PBXFileReference;[\s\S]*?\};$/gm;
  const objects = new Map();
  for (const match of sectionText.matchAll(entryRegex)) {
    objects.set(match[1], match[0]);
  }
  return objects;
}

function parsePath(rawBody) {
  const match = rawBody.match(/\bpath = (?:"([^"]+)"|([^;]+));/);
  return match ? (match[1] ?? match[2]).trim() : null;
}

function parseSourceTree(rawBody) {
  const match = rawBody.match(/\bsourceTree = (?:"([^"]+)"|([^;]+));/);
  return match ? (match[1] ?? match[2]).trim() : null;
}

function normalizeRelative(filePath) {
  return filePath.split(path.sep).join("/");
}

function collectSwiftFiles(rootDir) {
  const entries = [];
  if (!fs.existsSync(rootDir)) {
    return entries;
  }

  for (const entry of fs.readdirSync(rootDir, { withFileTypes: true })) {
    const absolute = path.join(rootDir, entry.name);
    if (entry.isDirectory()) {
      entries.push(...collectSwiftFiles(absolute));
      continue;
    }
    if (entry.isFile() && entry.name.endsWith(".swift")) {
      entries.push(absolute);
    }
  }

  return entries;
}

const pbxproj = fs.readFileSync(projectPath, "utf8");
const fileReferenceSection = pbxproj.match(
  /\/\* Begin PBXFileReference section \*\/([\s\S]*?)\/\* End PBXFileReference section \*\//
);
const groupSection = pbxproj.match(
  /\/\* Begin PBXGroup section \*\/([\s\S]*?)\/\* End PBXGroup section \*\//
);
const mainGroupMatch = pbxproj.match(/\bmainGroup = ([A-Za-z0-9]+)\b/);

if (!fileReferenceSection || !groupSection || !mainGroupMatch) {
  console.error("Unable to parse project.pbxproj structure.");
  process.exit(2);
}

const fileReferences = parseFileReferences(fileReferenceSection[1]);
const groups = parseObjects(groupSection[1]);
const mainGroup = mainGroupMatch[1];
const parentByChild = new Map();

for (const [groupID, body] of groups) {
  const childrenMatch = body.match(/\bchildren = \(([\s\S]*?)\n\t\t\t\);/);
  if (!childrenMatch) {
    continue;
  }

  const childIDs = [...childrenMatch[1].matchAll(/\b([A-Za-z0-9]+)\b\s+\/\*/g)].map(
    (match) => match[1]
  );
  for (const childID of childIDs) {
    parentByChild.set(childID, groupID);
  }
}

function resolveGroupPrefix(groupID) {
  const segments = [];
  let currentID = groupID;

  while (currentID) {
    const body = groups.get(currentID);
    if (!body) {
      break;
    }

    const groupPath = parsePath(body);
    if (groupPath) {
      segments.unshift(groupPath);
    }

    if (currentID === mainGroup) {
      break;
    }

    const sourceTree = parseSourceTree(body);
    if (sourceTree && sourceTree !== "<group>") {
      break;
    }

    currentID = parentByChild.get(currentID);
  }

  return segments;
}

function resolveFileReference(fileID, body) {
  const filePath = parsePath(body);
  if (!filePath || !filePath.endsWith(".swift")) {
    return null;
  }

  const sourceTree = parseSourceTree(body);
  if (sourceTree && sourceTree !== "<group>" && sourceTree !== "SOURCE_ROOT") {
    return null;
  }

  const directAbsolutePath = path.join(repoRoot, filePath);
  if (fs.existsSync(directAbsolutePath)) {
    return normalizeRelative(filePath);
  }

  const parentGroup = parentByChild.get(fileID);
  const resolvedSegments = [...resolveGroupPrefix(parentGroup), filePath];
  const resolvedPath = normalizeRelative(path.join(...resolvedSegments));
  const resolvedAbsolutePath = path.join(repoRoot, resolvedPath);

  return fs.existsSync(resolvedAbsolutePath) ? resolvedPath : null;
}

const managedSwiftFiles = new Set();
for (const [fileID, body] of fileReferences) {
  const resolved = resolveFileReference(fileID, body);
  if (resolved) {
    managedSwiftFiles.add(resolved);
  }
}

const diskSwiftFiles = scanRoots
  .flatMap((root) => collectSwiftFiles(path.join(repoRoot, root)))
  .map((absolutePath) => normalizeRelative(path.relative(repoRoot, absolutePath)))
  .sort();

const orphanedSwiftFiles = diskSwiftFiles.filter((filePath) => !managedSwiftFiles.has(filePath));
const missingManagedSwiftFiles = [...managedSwiftFiles]
  .filter((filePath) => !fs.existsSync(path.join(repoRoot, filePath)))
  .sort();

if (orphanedSwiftFiles.length || missingManagedSwiftFiles.length) {
  if (orphanedSwiftFiles.length) {
    console.error("Swift files on disk but outside the Xcode project:");
    for (const filePath of orphanedSwiftFiles) {
      console.error(`- ${filePath}`);
    }
  }

  if (missingManagedSwiftFiles.length) {
    if (orphanedSwiftFiles.length) {
      console.error("");
    }
    console.error("Swift files referenced by the Xcode project but missing on disk:");
    for (const filePath of missingManagedSwiftFiles) {
      console.error(`- ${filePath}`);
    }
  }

  process.exit(1);
}

console.log(`Project source check passed for ${managedSwiftFiles.size} Swift files.`);
