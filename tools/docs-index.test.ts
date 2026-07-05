const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('docs index and codebase tour link current assembler and game direction docs', () => {
  const readme = readFileSync(resolve(root, 'docs/README.md'), 'utf8');
  const codebase = readFileSync(resolve(root, 'docs/codebase.md'), 'utf8');

  for (const link of [
    '[TecMate Self-Hosted Assembler Direction](tecmate-self-hosted-assembler.md)',
    '[Profile Preprocessor Contract](profile-preprocessor-contract.md)',
    '[Polling State Runtime](polling-state-runtime.md)',
    '[Profile TEC-FS Packaging](profile-tecfs-packaging.md)',
    '[Input Polling ABI](input-polling-abi.md)',
    '[VDU/TMS Minimum Primitives](vdu-tms-minimum-primitives.md)',
    '[TECM8 Game Creation Mission](gamer.md)',
    '[Gamer Vertical Slice Specification](gamer-vertical-slice.md)',
    '[Game-Facing Register Contracts](game-register-contracts.md)',
  ]) {
    assert.match(readme, new RegExp(link.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  }
  assert.match(codebase, /self-hosted-assembler\.md/);
  assert.match(codebase, /source\/binary\/map artifact convention/);
  assert.match(codebase, /profile-preprocessor-contract\.md/);
  assert.match(codebase, /emit ordinary inspectable assembly/);
  assert.match(codebase, /polling-state-runtime\.md/);
  assert.match(codebase, /compact loop-based state model/);
  assert.match(codebase, /profile-tecfs-packaging\.md/);
  assert.match(codebase, /source, resource, generated artifact, and\s+runtime package roles/);
  assert.match(codebase, /input-polling-abi\.md/);
  assert.match(codebase, /cooperative input polling ABI/);
  assert.match(codebase, /vdu-tms-minimum-primitives\.md/);
  assert.match(codebase, /minimum bank-1 VDU\/TMS9918 service\s+surface/);
  assert.match(codebase, /gamer\.md/);
  assert.match(codebase, /gamer-vertical-slice\.md/);
  assert.match(codebase, /game runtime slice and service contract/);
  assert.match(codebase, /game-register-contracts\.md/);
});
