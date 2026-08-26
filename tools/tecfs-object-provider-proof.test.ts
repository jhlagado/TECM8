const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');

const root = resolve(__dirname, '..');
const read = (path: string): string => readFileSync(resolve(root, path), 'utf8');

test('native object provider is wired through the public 91h gateway', () => {
  const bank0 = read('roms/tec1g/tecm8/expansion/bank0.asm');
  const bank2 = read('roms/tec1g/tecm8/expansion/bank2.asm');
  const abi = read('roms/tec1g/tecm8/expansion/bank_ops.asmi');
  const proof = read('proofs/tecfs-bank/tecfs-object-provider-proof.asm');
  const runner = read('tools/run-tecfs-object-provider-proof.ts');
  const format = read('tools/tm8/format.ts');
  const pkg = JSON.parse(read('package.json'));

  assert.match(bank0, /NUCLEUS_OBJECT,TFS_BANK[\s\S]*TFS_SVC_OBJECT/);
  assert.match(bank2, /cp TFS_SVC_OBJECT[\s\S]*jp z,tecfsObjectImpl/);
  assert.match(bank2, /tecfsObjectCommit:[\s\S]*tecfsObjectSealDescriptor/);
  assert.match(bank2, /TFS_OBJECT_HANDLE_POISONED/);
  assert.match(abi, /TFS_OBJECT_SLOT_COUNT\s+\.equ 8/);
  assert.match(abi, /TFS_OBJECT_GEN_SECTORS\s+\.equ 128/);
  assert.match(abi, /TFS_OBJECT_DESC_BLOCK\s+\.equ 10/);
  assert.match(abi, /TFS_OBJECT_DATA_BLOCK\s+\.equ 256/);
  assert.match(format, /toolDescriptorStartBlock: 10/);
  assert.match(format, /toolDataStartBlock: 256/);
  assert.match(proof, /ld c,NUCLEUS_OBJECT[\s\S]*rst 10H/);
  assert.match(proof, /\.db 0x00,0x1A,0x7F,0x80,0xFF/);
  assert.match(proof, /NucleusStatusStorage[\s\S]*NucleusObjectAbort/);
  assert.match(runner, /tecfsMon3FileWrite[\s\S]*wantWriteFault/);
  assert.equal(
    pkg.scripts['proof:tecfs-object-provider'],
    'node --experimental-strip-types tools/run-tecfs-object-provider-proof.ts',
  );
  assert.match(pkg.scripts.check, /npm run proof:tecfs-object-provider/);
});
