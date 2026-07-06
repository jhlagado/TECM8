const { strict: assert } = require('node:assert');
const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { test } = require('node:test');

const root = resolve(__dirname, '..');

function readRepoFile(path: string): string {
  return readFileSync(resolve(root, path), 'utf8');
}

test('editor design documents the structured display model constants', () => {
  const docs = readRepoFile('docs/editor-design.md');

  assert.match(docs, /first ROM editor should be a small source editor/);
  assert.match(docs, /VDU\/TMS9918 text path first and keep GLCD support deferred/);
  assert.match(docs, /ROM MVP target:[\s\S]*TMS9918 VDU: 32 columns x 24 rows/);
  assert.match(docs, /Legacy\/reference target:[\s\S]*GLCD: 20 columns x 10 rows/);
  assert.match(docs, /rich TECM8 profile[\s\S]*VDU\/TMS9918 text plus matrix\s+keyboard/);
  assert.doesNotMatch(docs, /first usable version, meaning GLCD plus matrix keyboard/);

  for (const phrase of [
    'TECM8_DISPLAY_GLCD_COLUMNS',
    'TECM8_DISPLAY_GLCD_ROWS',
    'TECM8_DISPLAY_EDIT_ROWS',
    'TECM8_DISPLAY_GUTTER_PIXELS',
    'TECM8_DISPLAY_Y_ORIGIN',
    'TECM8_DISPLAY_STATUS_ROW',
    'TECM8_DISPLAY_MARKER_BREAKPOINT',
    'TECM8_DISPLAY_MARKER_COPY_SOURCE',
    'TECM8_DISPLAY_MARKER_MOVE_SOURCE',
  ]) {
    assert.match(docs, new RegExp(`\\b${phrase}\\b`));
  }
});

test('editor design defines a compact ROM MVP file-buffer ABI', () => {
  const docs = readRepoFile('docs/editor-design.md');

  assert.match(docs, /## ROM MVP File Buffer ABI/);
  assert.match(docs, /one compact source-file buffer contract/);
  assert.match(docs, /not by moving the old GLCD editor wholesale into expansion ROM/);
  assert.match(docs, /project-main source target already\s+resolved by the shell/);
  assert.match(docs, /32-byte source records/);
  assert.match(docs, /dirty flags\s+byte, bit 0 means buffer changed/);
  assert.match(docs, /result code\s+byte, compatible with SHL_RESULT_\*/);
  assert.match(docs, /TEC-FS as the file authority/);
  assert.match(docs, /bank 0 should not parse paths\s+or scan catalogues on the editor's behalf/);
  assert.match(docs, /one source file open at a time/);
  assert.match(docs, /explicit save only/);
  assert.match(docs, /VDU\/TMS9918 text rendering first, with GLCD support deferred unless needed/);
  assert.match(docs, /ROM\s+MVP should be driven by this small file-buffer ABI/);
});

test('structured display model has assembly entry points', () => {
  const source = readRepoFile('src/display-model.asm');
  const equates = readRepoFile('src/tecm8-equates.asm');

  for (const label of [
    'DisplayInit',
    'DisplayRenderScreen',
    'DisplayRenderLine',
    'DisplayRenderGutter',
    'DisplayRenderCursorCell',
    'DisplayEraseCursorCell',
  ]) {
    assert.match(source, new RegExp(`^@${label}:`, 'm'));
  }
  for (const constant of [
    'TECM8_DISPLAY_GLCD_COLUMNS',
    'TECM8_DISPLAY_GLCD_ROWS',
    'TECM8_DISPLAY_EDIT_ROWS',
    'TECM8_DISPLAY_GUTTER_PIXELS',
    'TECM8_DISPLAY_Y_ORIGIN',
    'TECM8_DISPLAY_Y_ORIGIN_BYTES',
    'TECM8_DISPLAY_STATUS_ROW',
  ]) {
    assert.match(source, new RegExp(`^${constant}\\s+\\.equ`, 'm'));
  }
  assert.match(source, /^TECM8_DISPLAY_Y_ORIGIN\s+\.equ\s+TECM8_GLCD_Y_ORIGIN$/m);
  assert.match(source, /^TECM8_DISPLAY_EDIT_ROWS\s+\.equ\s+TECM8_GLCD_ROWS$/m);
  assert.match(source, /^TECM8_DISPLAY_STATUS_ROW\s+\.equ\s+9$/m);
  assert.match(source, /^TECM8_DISPLAY_Y_ORIGIN_BYTES\s+\.equ\s+TECM8_DISPLAY_Y_ORIGIN \* TECM8_DISPLAY_ROW_BYTES$/m);
  assert.match(source, /^MON3_TGBUF\s+\.equ\s+TECM8_MON3_GLCD_TGBUF$/m);
  assert.match(equates, /^TECM8_GLCD_Y_ORIGIN\s+\.equ\s+2$/m);
  assert.match(equates, /^TECM8_GLCD_ROWS\s+\.equ\s+10$/m);
  assert.match(equates, /^TECM8_MON3_GLCD_TGBUF\s+\.equ\s+0x13C0$/m);
  assert.match(source, /@DisplayRenderGutter:\n\s+LD\s+\(DisplayRow\),A/);
  assert.match(source, /@DisplayRenderScreen:\n\s+LD\s+A,\(DisplayRenderScreenCount\)\n\s+INC\s+A\n\s+LD\s+\(DisplayRenderScreenCount\),A\n\s+LD\s+\(DisplayCursor\),HL\n\s+LD\s+A,TECM8_DISPLAY_EDIT_ROWS/);
  assert.match(source, /@DisplayInit:\n\s+CALL\s+BiosDisplayInit\n\s+RET\s+C\n\s+CALL\s+BiosDisplayClear/);
  assert.doesNotMatch(source, /TECM8_DISPLAY_TOP_ROW/);
  assert.doesNotMatch(source, /TECM8_DISPLAY_FIRST_EDIT_ROW/);
  assert.doesNotMatch(source, /TECM8_DISPLAY_BOTTOM_ROW/);
  assert.match(source, /AND\s+0x0F/);
  assert.match(source, /@DisplayRenderCursorCell:/);
  assert.match(source, /@DisplayEraseCursorCell:/);
  assert.match(source, /CP\s+TECM8_DISPLAY_EDIT_ROWS/);
  assert.match(source, /CP\s+TECM8_DISPLAY_MAX_TEXT_CHARS/);
  assert.doesNotMatch(source, /CALL\s+GlcdTileFlushRow/);
  assert.match(source, /CALL\s+GlcdTileMarkCellDirty/);
  assert.match(source, /@DisplayMarkCursorDirty:/);
  assert.match(source, /DEC\s+A\n\s+LD\s+C,A\n\s+CALL\s+GlcdTileMarkCellDirty/);
  assert.match(source, /DisplayCursorSavedBytes:/);
  assert.match(source, /TECM8_DISPLAY_MARKER_COPY_SOURCE\s+\.equ\s+8/);
  assert.match(source, /TECM8_DISPLAY_MARKER_MOVE_SOURCE\s+\.equ\s+16/);
  assert.match(source, /DisplaySawtoothPatternTable:\n\s+\.db\s+0x80,0xC0,0xE0,0xF0,0xE0,0xC0/);
  assert.match(source, /DisplayCursorFirstMaskTable:\n\s+\.db\s+0x80,0x40,0x20,0x10,0x08,0x04,0x02,0x01/);
  assert.match(source, /DisplayCursorSecondMaskTable:\n\s+\.db\s+0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00/);
  assert.match(source, /DisplayRenderScreenCount:/);
  assert.match(source, /LD\s+\(DisplayCursorOriginalByte\),A/);
  assert.match(source, /CALL\s+DisplayMeasureTextExtent/);
  assert.match(source, /CALL\s+DisplayPrepareTextTail/);
  assert.match(source, /CALL\s+DisplayClearTextTail/);
  assert.match(source, /DisplayRowTextExtent:/);
  assert.match(source, /DisplayTailCount:/);
  assert.match(source, /CALL\s+GlcdTileDrawTextRun/);
  assert.doesNotMatch(source, /CALL\s+BiosDisplayDrawCharAt/);
  assert.match(source, /LD\s+HL,MON3_TGBUF\n\s+LD\s+DE,TECM8_DISPLAY_Y_ORIGIN_BYTES\n\s+ADD\s+HL,DE\n\s+LD\s+DE,TECM8_DISPLAY_ROW_STRIDE/);
  assert.doesNotMatch(source, /CALL\s+BiosDisplayPutString/);
});

test('structured GLCD proof calls the display model and renders markers', () => {
  assert.ok(existsSync(resolve(root, 'proofs/display/structured-screen-proof.asm')));
  const source = readRepoFile('proofs/display/structured-screen-proof.asm');
  assert.match(source, /LD\s+A,1\n\s+LD\s+C,7\n\s+CALL\s+DisplayRenderCursorCell[\s\S]*?CALL\s+DrainDisplayWork/);

  assert.match(source, /CALL\s+DisplayInit/);
  assert.match(source, /CALL\s+DisplayRenderScreen/);
  assert.match(source, /CALL\s+DisplayRenderLine/);
  assert.match(source, /LD\s+HL,0x1000\n\s+LD\s+\(MON3_VPORT\),HL/);
  assert.match(source, /CALL\s+GlcdTileFlushFull/);
  assert.match(source, /\.include\s+"..\/..\/src\/glcd-tile\.asm"/);
  assert.match(source, /\bTECM8_DISPLAY_MARKER_BREAKPOINT\b/);
  assert.match(source, /\bTECM8_DISPLAY_MARKER_COPY_SOURCE\b/);
  assert.match(source, /\bTECM8_DISPLAY_MARKER_MOVE_SOURCE\b/);
  assert.match(source, /\.include\s+"..\/..\/src\/display-model\.asm"/);
});

test('structured display proof is wired into package checks', () => {
  const packageJson = readRepoFile('package.json');
  const runner = readRepoFile('tools/run-display-proof.ts');

  assert.match(packageJson, /"proof:display:structured"/);
  assert.match(packageJson, /proof:display:structured/);
  assert.match(runner, /verifyStructuredScreen/);
  assert.match(runner, /mon3Tgbuf = 0x13c0/);
  assert.match(runner, /visible .*gutter bits/);
  assert.match(runner, /sawtooth gutter bits/);
  assert.match(runner, /did not render .* text pixels in TGBUF/);
  assert.match(runner, /left stale pixels after shorter row redraw/);
});

test('display proofs do not write stale MON3 scroll-buffer addresses', () => {
  const smokeProof = readRepoFile('proofs/display/glcd-smoke-proof.asm');

  assert.doesNotMatch(smokeProof, /\b0x1000\b/);
});
