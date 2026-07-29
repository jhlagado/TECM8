const { strict: assert } = require('node:assert');
const { resolve } = require('node:path');
const { test } = require('node:test');
const {
  debug80Mon3BundleRoot,
  debug80Root,
  debug80RuntimeRoot,
  loadDebug80RuntimeModules,
  loadExpansionRomImage,
} = require('./debug80-integration.ts');

const tecm8Root = resolve(__dirname, '..');

test('Debug80 integration resolves the current sibling monorepo layout', () => {
  const expectedRoot = resolve(process.env.DEBUG80_ROOT ?? resolve(tecm8Root, '..', 'debug80'));
  assert.equal(debug80Root(), expectedRoot);
  assert.equal(
    debug80RuntimeRoot(),
    resolve(process.env.DEBUG80_RUNTIME_ROOT ?? resolve(expectedRoot, 'packages/debug80-runtime/dist')),
  );
  assert.equal(
    debug80Mon3BundleRoot(),
    resolve(
      process.env.DEBUG80_MON3_BUNDLE_ROOT ??
        resolve(expectedRoot, 'apps/debug80-vscode/resources/bundles/tec1g/mon3/v1'),
    ),
  );
});

test('Debug80 integration loads the current ESM runtime exports', async () => {
  const modules = await loadDebug80RuntimeModules();
  assert.equal(typeof modules.createTec1gRuntime, 'function');
  assert.equal(typeof modules.createTec1gMemoryHooks, 'function');
  assert.equal(typeof modules.applyExpansionRomMemory, 'function');
  assert.equal(typeof modules.createZ80Runtime, 'function');
});

test('Debug80 integration preserves the packed TECM8 expansion bank order', () => {
  const image = loadExpansionRomImage(
    resolve(tecm8Root, 'roms/tec1g/tecm8/expansion/expansion.bin'),
  );
  assert.equal(image.banks.length, 9);
  assert.equal(image.banks.every((bank: Uint8Array) => bank.length === 0x4000), true);
  assert.deepEqual(image.memory.subarray(0x8000, 0xc000), image.banks[0]);
  assert.deepEqual(image.memory.subarray(0xc000, 0x10000), image.banks[1]);
});
