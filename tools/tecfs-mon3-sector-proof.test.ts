const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');

const root = resolve(__dirname, '..');
const read = (path: string): string => readFileSync(resolve(root, path), 'utf8');

test('bank 5 exposes a real MON3 VOLUME.TM8 sector driver', () => {
  const bank5 = read('roms/tec1g/tecm8/expansion/bank5.asm');
  const bank2 = read('roms/tec1g/tecm8/expansion/bank2.asm');
  const proof = read('proofs/tecfs-bank/tecfs-mon3-sector-proof.asm');
  const runner = read('tools/run-tecfs-mon3-sector-proof.ts');
  const pkg = JSON.parse(read('package.json'));

  assert.match(bank5, /\.org\s+TFS_MON3_FILE_DRIVER[\s\S]*Tecm8Mon3FileDriverEntry:/);
  assert.match(bank5, /call openFile/);
  assert.match(bank5, /call FATgetSector/);
  assert.match(bank5, /call IDEreadSector/);
  assert.match(bank5, /push bc[\s\S]*push de[\s\S]*call IDEwriteSector/);
  assert.match(bank5, /ld hl,\(TFS_PARAM_SECTOR_2\)[\s\S]*cp 0x20/);
  assert.match(bank5, /\.include "\.\.\/monitor\/pata_fat32\.asm"/);
  assert.match(bank2, /ld a,TFS_BRIDGE_BANK[\s\S]*ld hl,TFS_MON3_FILE_DRIVER/);
  assert.match(proof, /0x00,0x1A,0x7F,0x80,0xFF/);
  assert.match(runner, /volume_start_byte_offset \+ 7 \* 512/);
  assert.equal(pkg.scripts['proof:tecfs-mon3-sector'],
    'node --experimental-strip-types tools/run-tecfs-mon3-sector-proof.ts');
  assert.match(pkg.scripts.check, /npm run proof:tecfs-mon3-sector/);
});
