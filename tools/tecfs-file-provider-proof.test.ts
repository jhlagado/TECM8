const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');

const root = resolve(__dirname, '..');
const read = (path: string): string => readFileSync(resolve(root, path), 'utf8');

test('ordinary TEC-FS files use the shared read-only tool-service profile', () => {
  const bank0 = read('roms/tec1g/tecm8/expansion/bank0.asm');
  const bank2 = read('roms/tec1g/tecm8/expansion/bank2.asm');
  const provider = read('roms/tec1g/tecm8/expansion/tecfs-file-provider.asm');
  const abi = read('roms/tec1g/tecm8/expansion/bank_ops.asmi');
  const proof = read('proofs/tecfs-bank/tecfs-file-provider-proof.asm');
  const runner = read('tools/run-tecfs-file-provider-proof.ts');
  const pkg = JSON.parse(read('package.json'));

  assert.match(bank0, /ZT_FILE,TFS_BANK[\s\S]*TFS_SVC_FILE/);
  assert.match(bank2, /cp TFS_SVC_FILE[\s\S]*jp z,tecfsFileImpl/);
  assert.match(provider, /ZT_FILE names a file with one binary byte/);
  assert.match(provider, /tecfsFileRead:[\s\S]*tecfsFileNextBlock/);
  assert.match(provider, /tecfsFileUnsupported:[\s\S]*ld a,ZT_UNSUP/);
  assert.match(abi, /ZT_OBJECT\s+\.equ\s+0x91/);
  assert.match(abi, /ZT_FILE\s+\.equ\s+0x92/);
  assert.match(abi, /NUCLEUS_OBJECT\s+\.equ\s+ZT_OBJECT/);
  assert.match(abi, /TFS_FILE_STATE_BASE\s+\.equ 0x3CD0/);
  assert.match(abi, /TFS_OBJECT_SECTOR_BUFFER\s+\.equ 0x3D00/);
  assert.match(proof, /ld c,ZT_FILE[\s\S]*rst 10H/);
  assert.match(proof, /ld de,4090[\s\S]*ld bc,32/);
  assert.match(proof, /ld de,0x7FFF[\s\S]*ld bc,1/);
  assert.match(runner, /tecfsMon3FileRead[\s\S]*wantReadFault/);
  assert.equal(
    pkg.scripts['proof:tecfs-file-provider'],
    'node --experimental-strip-types tools/run-tecfs-file-provider-proof.ts',
  );
});
