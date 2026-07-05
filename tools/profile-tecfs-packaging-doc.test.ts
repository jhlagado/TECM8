const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/profile-tecfs-packaging.md'), 'utf8');

test('profile TEC-FS packaging keeps tecm8 project config authoritative', () => {
  assert.match(doc, /Profile projects should use TEC-FS as the machine-facing package format/);
  assert.match(doc, /must not create a\s+parallel storage system/);
  assert.match(doc, /\/tecm8\.prj/);
  assert.match(doc, /Shell v1 only accepts `tm8project` and `main`/);
  assert.match(doc, /explicit project\s+format\/version bump/);
  assert.match(doc, /tm8project=2/);
  assert.doesNotMatch(doc, /tm8project=1\nmain=\/src\/main\.asm\nprofile=/);
  assert.match(doc, /main=\/src\/main\.asm/);
  assert.match(doc, /profile=\/profile\/game\.tm8p/);
  assert.match(doc, /not a second source of truth/);
});

test('profile TEC-FS packaging defines ordinary file roles', () => {
  assert.match(doc, /\/generated\/profile\.generated\.asm/);
  assert.match(doc, /\/build\/main\.bin/);
  assert.match(doc, /\/build\/main\.map/);
  assert.match(doc, /\/build\/main\.pkg/);
  assert.match(doc, /Profile source[\s\S]*`TFS_FILE_SOURCE` or later `TFS_FILE_PROFILE`/);
  assert.match(doc, /Generated assembly[\s\S]*`TFS_FILE_SOURCE`/);
  assert.match(doc, /Binary output[\s\S]*`TFS_FILE_BINARY`/);
  assert.match(doc, /Package manifest[\s\S]*`TFS_FILE_GAME`/);
  assert.match(doc, /New TEC-FS file types should be added only when/);
  assert.match(doc, /existing\s+`TFS_FILE_GAME` game\/application package role/);
  assert.doesNotMatch(doc, /TFS_FILE_PROJECT` or later `TFS_FILE_PACKAGE/);
});

test('profile TEC-FS packaging separates runtime package from source authority', () => {
  assert.match(doc, /`\/build\/main\.pkg` is the profile runtime summary/);
  assert.match(doc, /runnable binary path/);
  assert.match(doc, /load address, end address, and run address/);
  assert.match(doc, /required display profile/);
  assert.match(doc, /resource table path or offset/);
  assert.match(doc, /derived output/);
  assert.match(doc, /source files win and the package should be rebuilt/);
});

test('profile TEC-FS packaging makes resources traceable and keeps shell generic', () => {
  assert.match(doc, /Source resources under `\/assets`/);
  assert.match(doc, /Generated resource tables under `\/generated`/);
  assert.match(doc, /resource id[\s\S]*resource type[\s\S]*TEC-FS path or packed offset/);
  assert.match(doc, /traceable back to\s+`\/assets\/player\.spr`/);
  assert.match(doc, /The shell should not need to understand every profile/);
  assert.match(doc, /Profile-specific setup beyond that belongs to the profile runtime or generated\s+startup code/);
});

test('profile TEC-FS packaging publishes size pressure', () => {
  assert.match(doc, /Profile packaging must publish sizes/);
  assert.match(doc, /generated assembly bytes/);
  assert.match(doc, /user behaviour code bytes where known/);
  assert.match(doc, /resource bytes/);
  assert.match(doc, /runtime\/package overhead bytes/);
  assert.match(doc, /final binary size/);
  assert.match(doc, /growth must be visible/);
});
