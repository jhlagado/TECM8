const { strict: assert } = require('node:assert');
const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { test } = require('node:test');

const root = resolve(__dirname, '..');

function readRepoFile(path: string): string {
  return readFileSync(resolve(root, path), 'utf8');
}

test('editor input module owns key-stream and live polling entry points', () => {
  const inputPath = resolve(root, 'src/editor-input.asm');

  assert.ok(existsSync(inputPath));
  const input = readRepoFile('src/editor-input.asm');
  const interaction = readRepoFile('src/editor-interaction.asm');

  for (const entry of ['EditorRunKeys', 'EditorRunModifiedKey', 'EditorRunLive']) {
    assert.match(input, new RegExp(`^@${entry}:`, 'm'));
    assert.doesNotMatch(interaction, new RegExp(`^@${entry}:`, 'm'));
  }

  assert.match(interaction, /^@EditorKeyLoop:/m);
  assert.match(interaction, /\.include\s+"editor-input\.asm"/);

  for (const stateByte of [
    'EditorKeyStreamPtr',
    'EditorLiveKeyBuffer',
    'EditorKeyStreamModifier',
    'EditorPendingModifier',
    'EditorPendingChar',
    'EditorInsertMode',
    'EditorQuitRequested',
  ]) {
    assert.match(input, new RegExp(`${stateByte}:\\n\\s+\\.(?:db|dw)`));
    assert.doesNotMatch(interaction, new RegExp(`${stateByte}:\\n\\s+\\.(?:db|dw)`));
  }
});
