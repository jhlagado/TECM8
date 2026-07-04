const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('docs index and codebase tour link current assembler and game direction docs', () => {
  const readme = readFileSync(resolve(root, 'docs/README.md'), 'utf8');
  const codebase = readFileSync(resolve(root, 'docs/codebase.md'), 'utf8');

  for (const text of [
    'TecMate Self-Hosted Assembler Direction',
    'TECM8 Game Creation Mission',
    'Gamer Vertical Slice Specification',
    'Game-Facing Register Contracts',
  ]) {
    assert.match(readme, new RegExp(text));
  }
  assert.match(codebase, /self-hosted-assembler\.md/);
  assert.match(codebase, /source\/binary\/map artifact convention/);
  assert.match(codebase, /gamer\.md/);
  assert.match(codebase, /gamer-vertical-slice\.md/);
  assert.match(codebase, /game runtime slice and service contract/);
  assert.match(codebase, /game-register-contracts\.md/);
});
