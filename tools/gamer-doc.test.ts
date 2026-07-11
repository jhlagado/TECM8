const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const profileDoc = readFileSync(resolve(root, 'docs/profile-preprocessor-contract.md'), 'utf8');
const pollingDoc = readFileSync(resolve(root, 'docs/polling-state-runtime.md'), 'utf8');
const roadmapDoc = readFileSync(resolve(root, 'docs/roadmap.md'), 'utf8');

test('profile direction frames profiles as preprocessors over ordinary assembly', () => {
  assert.match(profileDoc, /profile preprocessor/i);
  assert.match(profileDoc, /ordinary assembly/i);
  assert.match(profileDoc, /generated/i);
  assert.match(profileDoc, /inspectable/i);
  assert.match(roadmapDoc, /game/i);
  assert.match(roadmapDoc, /proving profile/i);
});

test('profile direction keeps the shared runtime loop-based rather than desktop-event based', () => {
  assert.match(pollingDoc, /cooperative/i);
  assert.match(pollingDoc, /poll/i);
  assert.match(pollingDoc, /dirty/i);
  assert.match(pollingDoc, /routine/i);
  assert.doesNotMatch(pollingDoc, /object-oriented event-driven/i);
});
