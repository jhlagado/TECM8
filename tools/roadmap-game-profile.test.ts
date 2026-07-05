const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const roadmap = readFileSync(resolve(root, 'docs/roadmap.md'), 'utf8');

test('roadmap frames game creation as a proving profile for general TecMate services', () => {
  assert.match(roadmap, /## Game Creation As A Proving Profile/);
  assert.match(roadmap, /should not\s+replace the general shell\/editor\/assembler\/debugger direction/);
  assert.match(roadmap, /first\s+serious application profile that proves those general services are coherent/);
  assert.match(roadmap, /TecMate shell\/editor\/assembler\/debugger[\s\S]*optional game tool profile[\s\S]*native Z80 game runtime/);
  assert.match(roadmap, /user AZM-subset behaviour routines/);
  assert.match(roadmap, /VDU, input, joystick, TEC-FS, and debugger services/);
  assert.match(roadmap, /Do not start a full game engine until the\s+shell, assembler, runner, and basic VDU\/input\/storage services can support it/);
});

test('roadmap links game direction documents from the proving-profile section', () => {
  assert.match(roadmap, /\[TECM8 Game Creation Mission\]\(gamer\.md\)/);
  assert.match(roadmap, /\[Gamer Vertical Slice Specification\]\(gamer-vertical-slice\.md\)/);
  assert.match(roadmap, /\[Game-Facing Register Contracts\]\(game-register-contracts\.md\)/);
  assert.match(roadmap, /\[Profile Preprocessor Contract\]\(profile-preprocessor-contract\.md\)/);
  assert.match(roadmap, /\[Polling State Runtime\]\(polling-state-runtime\.md\)/);
  assert.match(roadmap, /\[Profile TEC-FS Packaging\]\(profile-tecfs-packaging\.md\)/);
  assert.match(roadmap, /\[Input Polling ABI\]\(input-polling-abi\.md\)/);
  assert.match(roadmap, /\[VDU\/TMS Minimum Primitives\]\(vdu-tms-minimum-primitives\.md\)/);
});
