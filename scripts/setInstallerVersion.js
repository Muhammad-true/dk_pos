const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const pubPath = path.join(root, 'pubspec.yaml');
const issPath = path.join(root, 'installer.iss');

function readPubspec() {
  return fs.readFileSync(pubPath, 'utf8');
}

function parsePubspecVersion(content) {
  const m = content.match(/^version:\s*(\d+\.\d+\.\d+)(?:\+(\d+))?\s*$/m);
  if (!m) {
    throw new Error(
      'В pubspec.yaml ожидается строка вида version: 1.2.3+4 (semver и опционально +build).'
    );
  }
  return {
    semver: m[1],
    build: m[2] !== undefined ? parseInt(m[2], 10) : 0,
  };
}

function writePubspecVersion(content, semver, build) {
  const line = build > 0 ? `version: ${semver}+${build}` : `version: ${semver}`;
  const next = content.replace(/^version:\s*.+$/m, line);
  if (next === content) {
    throw new Error('Не удалось заменить version в pubspec.yaml');
  }
  fs.writeFileSync(pubPath, next, 'utf8');
}

function writeIssVersion(v) {
  let iss = fs.readFileSync(issPath, 'utf8');
  iss = iss.replace(/#define MyAppVersion ".*?"/, `#define MyAppVersion "${v}"`);
  fs.writeFileSync(issPath, iss, 'utf8');
}

function bumpPatch(ver) {
  const m = String(ver).trim().match(/^(\d+)\.(\d+)\.(\d+)/);
  if (!m) {
    throw new Error(`Не удалось разобрать semver: "${ver}"`);
  }
  return `${m[1]}.${m[2]}.${parseInt(m[3], 10) + 1}`;
}

const arg = process.argv[2];

if (arg === '--sync' || arg === undefined || arg === '') {
  const { semver } = parsePubspecVersion(readPubspec());
  writeIssVersion(semver);
  console.log(`[setInstallerVersion] Синхронизация: MyAppVersion = ${semver} (из pubspec.yaml → installer.iss)`);
  process.exit(0);
}

if (arg === '--bump-patch' || arg === 'bump') {
  const content = readPubspec();
  const { semver, build } = parsePubspecVersion(content);
  const nextSemver = bumpPatch(semver);
  const nextBuild = build + 1;
  writePubspecVersion(content, nextSemver, nextBuild);
  writeIssVersion(nextSemver);
  console.log(
    `[setInstallerVersion] Патч: ${semver}+${build} → ${nextSemver}+${nextBuild} (pubspec.yaml + installer.iss)`
  );
  process.exit(0);
}

if (!/^\d+\.\d+\.\d+/.test(arg)) {
  console.error(
    'Использование:\n' +
      '  node scripts/setInstallerVersion.js              — подтянуть version из pubspec.yaml в installer.iss\n' +
      '  node scripts/setInstallerVersion.js bump         — +1 патч и +1 к build (1.0.12+1 → 1.0.13+2)\n' +
      '  node scripts/setInstallerVersion.js 1.2.3        — зафиксировать 1.2.3+1 в pubspec и .iss'
  );
  process.exit(1);
}

const explicit = arg.match(/^(\d+\.\d+\.\d+)/)[1];
const content = readPubspec();
writePubspecVersion(content, explicit, 1);
writeIssVersion(explicit);
console.log(`[setInstallerVersion] Версия ${explicit}+1 записана в pubspec.yaml и installer.iss`);
process.exit(0);
