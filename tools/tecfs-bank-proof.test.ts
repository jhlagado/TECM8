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

  assert.match(proof, /ld a,0x1F[\s\S]*ld a,TFS_SVC_SELECT_VOLUME[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp TFS_ERR_BAD_VOLUME[\s\S]*ld a,\(TFS_PARAM_ACTIVE_VOLUME\)[\s\S]*cp 0x1E/);
  assert.match(proof, /ld a,0x1D[\s\S]*ld a,TFS_SVC_SELECT_VOLUME[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*ld a,TFS_SVC_MAP_BLOCK[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp 0x74[\s\S]*ld a,TFS_SVC_TRANSLATE_SECTOR[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp 0x74/);
  assert.match(runner, /active TEC-FS volume/);
  assert.match(runner, /assertEqual\(params\[0\], 0x1d, 'active TEC-FS volume'\)/);
  assert.match(runner, /assertEqual\(params\[1\], 0x1d, 'last requested TEC-FS volume'\)/);
  assert.match(runner, /assertEqual\(params\[16\], 0x74, 'TEC-FS mapped sector byte 2'\)/);
  assert.match(doc, /leaves the previous active\s+volume\s+unchanged/);
});

test('TEC-FS bank proof covers installable sector driver dispatch', () => {
  const proof = readFileSync(resolve(root, 'proofs/tecfs-bank/tecfs-bank-proof.asm'), 'utf8');
  const runner = readFileSync(resolve(root, 'tools/run-tecfs-bank-proof.ts'), 'utf8');
  const bank5 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank5.asm'), 'utf8');
  const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-banked-service-abi.md'), 'utf8');

  assert.match(proof, /ld a,0x05[\s\S]*ld \(TFS_PARAM_DRIVER_BANK\),a[\s\S]*ld hl,0x8000[\s\S]*ld \(TFS_PARAM_DRIVER_ADDR_LO\),hl/);
  assert.match(proof, /ld a,TFS_SVC_READ[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp 0x85[\s\S]*ld a,\(0x6000\)[\s\S]*cp TFS_PROOF_READ_MARKER/);
  assert.match(proof, /ld a,TFS_SVC_WRITE[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp 0x85/);
  assert.match(runner, /assertEqual\(params\[29\], 0x05, 'TEC-FS driver bank'\)/);
  assert.match(runner, /assertEqual\(params\[31\], 0x80, 'TEC-FS driver address high byte'\)/);
  assert.match(bank5, /@Tecm8ExpansionBank5Entry:[\s\S]*cp TFS_DRIVER_OP_READ[\s\S]*jp z,tecfsProofDriverRead[\s\S]*cp TFS_DRIVER_OP_WRITE/);
  assert.match(bank5, /tecfsProofDriverRead:[\s\S]*ld a,TFS_PROOF_READ_MARKER[\s\S]*ld \(hl\),a/);
  assert.match(doc, /installed sector-driver vector/);
});

test('TEC-FS direction documents the volume directory contract', () => {
  const direction = readFileSync(resolve(root, 'docs/mon3/tec-fs-direction.md'), 'utf8');
  const bankOps = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank_ops.asmi'), 'utf8');

  assert.match(direction, /^## Volume Directory Contract/m);
  assert.match(direction, /locator sector lives at absolute LBA 1/);
  assert.match(direction, /LBA 0 is the MBR/);
  assert.match(direction, /magic: "TFS1"/);
  assert.match(direction, /volume entry size: 10h/);
  assert.match(direction, /first volume entry/);
  assert.match(direction, /01h user, 02h reserved-work/);
  assert.match(direction, /absolute start sector, little-endian/);
  assert.match(direction, /user volume count: 30/);
  assert.match(direction, /reserved work volume: 30/);
  assert.match(direction, /total selectable volumes: 31/);
  assert.match(direction, /volume sectors: 262,144 = 0x00040000/);
  assert.match(direction, /allocation block size: 4 KiB/);
  assert.match(direction, /allocation blocks per volume: 32,768/);
  assert.match(direction, /absolute_sd_sector = volume_start_sector\[active_volume\] \+ sector_inside_volume/);
  assert.match(direction, /not the live allocation system used by TEC-FS after\s+mount/);
  assert.match(direction, /ordinary file\s+open\/save code should not present it as a normal user drive/);

  for (const [name, value] of [
    ['TFS_LOC_MAGIC_0', '0x54'],
    ['TFS_LOC_MAGIC_1', '0x46'],
    ['TFS_LOC_MAGIC_2', '0x53'],
    ['TFS_LOC_MAGIC_3', '0x31'],
    ['TFS_LOC_VERSION', '0x01'],
    ['TFS_LOC_HEADER_BYTES', '0x20'],
    ['TFS_LOC_ENTRY_BYTES', '0x10'],
    ['TFS_LOC_OFFSET_ENTRIES', '0x20'],
    ['TFS_LOC_ENTRY_START_LBA', '0x03'],
    ['TFS_LOC_ENTRY_SECTORS', '0x07'],
    ['TFS_LOC_ROLE_USER', '0x01'],
    ['TFS_LOC_ROLE_WORK', '0x02'],
    ['TFS_LOC_FLAG_ACTIVE', '0x01'],
  ]) {
    assert.match(bankOps, new RegExp(`^${name}\\s+\\.equ\\s+${value}`, 'm'));
  }
});
