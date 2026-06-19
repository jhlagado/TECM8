const { strict: assert } = require('node:assert');
const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { test } = require('node:test');

const root = resolve(__dirname, '..');

function readRepoFile(path: string): string {
  return readFileSync(resolve(root, path), 'utf8');
}

test('display service exposes editor-facing GLCD operations as contract wrappers', () => {
  const servicePath = resolve(root, 'src/tecm8-display-service.asm');

  assert.ok(existsSync(servicePath));
  const source = readRepoFile('src/tecm8-display-service.asm');

  for (const [wrapper, target] of [
    ['Tecm8DisplayStep', 'GlcdTileStep'],
    ['Tecm8DisplayMarkRowDirty', 'GlcdTileMarkRowDirty'],
    ['Tecm8DisplayMarkCellDirty', 'GlcdTileMarkCellDirty'],
    ['Tecm8DisplayMarkGutterDirty', 'GlcdTileMarkGutterDirty'],
    ['Tecm8DisplayFlushFull', 'GlcdTileFlushFull'],
    ['Tecm8DisplayFlushRow', 'GlcdTileFlushRow'],
    ['Tecm8DisplayRenderLine', 'DisplayRenderLine'],
    ['Tecm8DisplayRenderCursorCell', 'DisplayRenderCursorCell'],
    ['Tecm8DisplayEraseCursorCell', 'DisplayEraseCursorCell'],
  ]) {
    assert.match(source, new RegExp(`^@${wrapper}:\\n\\s+JP\\s+${target}$`, 'm'));
  }

  assert.match(source, /;! out A,carry,zero\n;! clobbers sign,parity,halfCarry,BC,DE,HL\n@Tecm8DisplayStep:/);
  assert.match(source, /;! in A,C,HL\n;! out carry\n;! clobbers zero,sign,parity,halfCarry,A,BC,DE,HL\n@Tecm8DisplayRenderLine:/);
  assert.match(source, /;! in A,C\n;! out A,carry,zero\n;! clobbers sign,parity,halfCarry,BC,DE,HL\n@Tecm8DisplayRenderCursorCell:/);
});

test('editor modules call display through the TECM8 display service boundary', () => {
  const interaction = readRepoFile('src/editor-interaction.asm');
  const input = readRepoFile('src/editor-input.asm');
  const cursor = readRepoFile('src/editor-cursor.asm');
  const render = readRepoFile('src/editor-render.asm');
  const viewport = readRepoFile('src/editor-viewport.asm');
  const navigation = readRepoFile('src/editor-navigation.asm');
  const block = readRepoFile('src/editor-block.asm');

  assert.match(input, /EditorLiveIdle:\n\s+CALL\s+Tecm8DisplayStep/);
  assert.doesNotMatch(interaction, /CALL\s+GlcdTileStep/);
  assert.doesNotMatch(input, /CALL\s+GlcdTileStep/);

  assert.match(cursor, /CALL\s+Tecm8DisplayRenderCursorCell/);
  assert.match(cursor, /CALL\s+Tecm8DisplayEraseCursorCell/);
  assert.doesNotMatch(cursor, /CALL\s+DisplayRenderCursorCell/);
  assert.doesNotMatch(cursor, /CALL\s+DisplayEraseCursorCell/);

  assert.match(render, /CALL\s+Tecm8DisplayMarkRowDirty/);
  assert.match(render, /CALL\s+Tecm8DisplayMarkCellDirty/);
  assert.match(render, /CALL\s+Tecm8DisplayMarkGutterDirty/);
  assert.doesNotMatch(render, /CALL\s+GlcdTileMark(?:Row|Cell|Gutter)Dirty/);

  assert.match(viewport, /CALL\s+Tecm8DisplayRenderLine/);
  assert.match(viewport, /CALL\s+Tecm8DisplayFlushRow/);
  assert.match(viewport, /CALL\s+Tecm8DisplayMarkCellDirty/);
  assert.match(viewport, /CALL\s+Tecm8DisplayMarkGutterDirty/);
  assert.doesNotMatch(viewport, /CALL\s+DisplayRenderLine/);
  assert.doesNotMatch(viewport, /CALL\s+GlcdTile(?:FlushRow|MarkCellDirty|MarkGutterDirty)/);

  assert.match(navigation, /CALL\s+Tecm8DisplayFlushFull/);
  assert.doesNotMatch(navigation, /CALL\s+GlcdTileFlushFull/);

  assert.match(block, /CALL\s+Tecm8DisplayMarkGutterDirty/);
  assert.doesNotMatch(block, /CALL\s+GlcdTileMarkGutterDirty/);
});
