const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');

const root = resolve(__dirname, '..');
const read = (path: string): string => readFileSync(resolve(root, path), 'utf8');

test('ROM editor has a real SD backend and bounded path lookup', () => {
  const bank0 = read('roms/tec1g/tecm8/expansion/bank0.asm');
  const bank2 = read('roms/tec1g/tecm8/expansion/bank2.asm');
  const bank4 = read('roms/tec1g/tecm8/expansion/bank4.asm');
  const bank5 = read('roms/tec1g/tecm8/expansion/bank5.asm');
  const proof = read('proofs/tecfs-bank/tecfs-mon3-file-proof.asm');
  const packageJson = JSON.parse(read('package.json'));

  assert.match(bank0, /ld hl,TFS_MON3_FILE_DRIVER[\s\S]*ld \(TFS_PARAM_DRIVER_ADDR_LO\),hl/);
  assert.match(bank0, /Tecm8ShellRunCheckEditPath:[\s\S]*SHL_TARGET_KIND_SOURCE_PATH/);
  assert.match(bank2, /tecfsFindPathImpl:[\s\S]*tecfsFindPrefix[\s\S]*tecfsFindCatalog/);
  assert.match(bank2, /tecfsCommitSourceMetaMon3:[\s\S]*call tecfsReadSectorImpl[\s\S]*call tecfsWriteSectorImpl/);
  assert.match(bank4, /TFS_SVC_FIND_PATH/);
  assert.match(bank5, /\.org\s+TFS_MON3_FILE_DRIVER[\s\S]*Tecm8Mon3FileDriverEntry:/);
  assert.match(bank5, /\.include "\.\.\/monitor\/pata_fat32\.asm"/);
  assert.match(proof, /EDT_SVC_RUN[\s\S]*EDT_STATE_SAVE_COUNT[\s\S]*EDT_SVC_RUN/);
  assert.equal(
    packageJson.scripts['proof:tecfs-mon3-file'],
    'node --experimental-strip-types tools/run-tecfs-mon3-file-proof.ts',
  );
  assert.match(packageJson.scripts.check, /proof:tecfs-mon3-file/);
});
