const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

function equate(source: string, name: string): number {
  const match = source.match(new RegExp(`^${name}\\s+\\.equ\\s+([^\\n;]+)`, 'm'));
  if (!match) {
    throw new Error(`missing equate ${name}`);
  }
  const raw = match[1]?.trim();
  assert.ok(raw, `missing equate value ${name}`);
  if (/^0x[0-9a-f]+$/i.test(raw)) {
    return Number.parseInt(raw.slice(2), 16);
  }
  if (/^[0-9]+$/.test(raw)) {
    return Number.parseInt(raw, 10);
  }
  throw new Error(`unsupported equate expression for ${name}: ${raw}`);
}

function le32(source: string, prefix: string): number {
  return (
    equate(source, `${prefix}_0`) |
    (equate(source, `${prefix}_1`) << 8) |
    (equate(source, `${prefix}_2`) << 16) |
    (equate(source, `${prefix}_3`) << 24)
  ) >>> 0;
}

test('TEC-FS standard geometry is internally consistent', () => {
  const bank2 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank2.asm'), 'utf8');
  const bankOps = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank_ops.asmi'), 'utf8');

  const volumeMiB = equate(bank2, 'TFS_VOLUME_MIB');
  const blockBytes = equate(bank2, 'TFS_BLOCK_BYTES');
  const volumeBlocks = equate(bank2, 'TFS_VOLUME_BLOCKS');
  const userVolumes = equate(bank2, 'TFS_USER_VOLUMES');
  const spareVolume = equate(bank2, 'TFS_SPARE_VOLUME');
  const totalVolumes = equate(bank2, 'TFS_TOTAL_VOLUMES');
  const volumeSectors = le32(bankOps, 'TFS_VOLUME_SECTORS');

  assert.equal(volumeMiB, 128);
  assert.equal(blockBytes, 4096);
  assert.equal(blockBytes / 512, 8);
  assert.equal(volumeSectors, 262144);
  assert.equal(volumeSectors * 512, volumeMiB * 1024 * 1024);
  assert.equal(volumeBlocks, 32768);
  assert.equal(volumeBlocks * blockBytes, volumeMiB * 1024 * 1024);
  assert.equal(userVolumes, 30);
  assert.equal(spareVolume, 30);
  assert.equal(totalVolumes, userVolumes + 1);
});

test('TEC-FS direction document records the same standard geometry', () => {
  const direction = readFileSync(resolve(root, 'docs/mon3/tec-fs-direction.md'), 'utf8');

  assert.match(direction, /128 MiB per image volume/);
  assert.match(direction, /TECFS00\.IMG \.\. TECFS29\.IMG\s+user volumes/);
  assert.match(direction, /TECFS30\.IMG\s+reserved work\/safety volume/);
  assert.match(direction, /volume sectors: 262,144 = 0x00040000/);
  assert.match(direction, /allocation block size: 4 KiB/);
  assert.match(direction, /allocation blocks per volume: 32,768/);
});
