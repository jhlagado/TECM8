const { existsSync } = require('node:fs');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('TEC-FS bank proof artifacts are wired into the repository', () => {
  assert.equal(existsSync(resolve(root, 'proofs/tecfs-bank/tecfs-bank-proof.asm')), true);
  assert.equal(existsSync(resolve(root, 'tools/run-tecfs-bank-proof.ts')), true);
});

test('package check runs the TEC-FS bank proof', () => {
  const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));
  assert.equal(pkg.scripts['proof:tecfs-bank'], 'node --experimental-strip-types tools/run-tecfs-bank-proof.ts');
  assert.match(pkg.scripts.check, /npm run proof:tecfs-bank/);
});

test('TEC-FS bank proof covers runtime volume selection in sector translation', () => {
  const proof = readFileSync(resolve(root, 'proofs/tecfs-bank/tecfs-bank-proof.asm'), 'utf8');
  const runner = readFileSync(resolve(root, 'tools/run-tecfs-bank-proof.ts'), 'utf8');
  const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-banked-service-abi.md'), 'utf8');

  assert.match(proof, /ld a,0x1F[\s\S]*farCall 0x02,TECM8_TECFS_SELECT_VOLUME[\s\S]*cp TECFS_ERR_BAD_VOLUME[\s\S]*ld a,\(TECFS_PARAM_ACTIVE_VOLUME\)[\s\S]*cp 0x1E/);
  assert.match(proof, /ld a,0x1D[\s\S]*farCall 0x02,TECM8_TECFS_SELECT_VOLUME[\s\S]*farCall 0x02,TECM8_TECFS_MAP_BLOCK[\s\S]*cp 0x74[\s\S]*farCall 0x02,TECM8_TECFS_TRANSLATE_SECTOR[\s\S]*cp 0x74/);
  assert.match(runner, /active TEC-FS volume/);
  assert.match(runner, /assertEqual\(params\[0\], 0x1d, 'active TEC-FS volume'\)/);
  assert.match(runner, /assertEqual\(params\[1\], 0x1d, 'last requested TEC-FS volume'\)/);
  assert.match(runner, /assertEqual\(params\[16\], 0x74, 'TEC-FS mapped sector byte 2'\)/);
  assert.match(doc, /leaves the previous active\s+volume\s+unchanged/);
});

test('TEC-FS direction documents the volume directory contract', () => {
  const direction = readFileSync(resolve(root, 'docs/mon3/tec-fs-direction.md'), 'utf8');

  assert.match(direction, /^## Volume Directory Contract/m);
  assert.match(direction, /locator sector lives at absolute LBA 1/);
  assert.match(direction, /LBA 0 is the MBR/);
  assert.match(direction, /user volume count: 30/);
  assert.match(direction, /reserved work volume: 30/);
  assert.match(direction, /total selectable volumes: 31/);
  assert.match(direction, /volume sectors: 262,144 = 0x00040000/);
  assert.match(direction, /allocation block size: 4 KiB/);
  assert.match(direction, /allocation blocks per volume: 32,768/);
  assert.match(direction, /absolute_sd_sector = volume_start_sector\[active_volume\] \+ sector_inside_volume/);
  assert.match(direction, /not the live allocation system used by TEC-FS after\s+mount/);
  assert.match(direction, /ordinary file\s+open\/save code should not present it as a normal user drive/);
});
