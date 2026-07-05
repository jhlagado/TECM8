const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const ops = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank_ops.asmi'), 'utf8');
const equates = readFileSync(resolve(root, 'src/tecm8-equates.asm'), 'utf8');

function equateExpression(source: string, name: string): string {
  const match = source.match(new RegExp(`^${name}\\s+\\.equ\\s+([^\\n;]+)`, 'm'));
  const expression = match?.[1];
  if (!expression) {
    throw new Error(`missing equate ${name}`);
  }
  return expression.trim();
}

function parseNumber(source: string, token: string): number {
  const trimmed = token.trim();
  if (/^0x[0-9a-f]+$/i.test(trimmed)) {
    return Number.parseInt(trimmed.slice(2), 16);
  }
  if (/^[0-9a-f]+h$/i.test(trimmed)) {
    return Number.parseInt(trimmed.slice(0, -1), 16);
  }
  if (/^[0-9]+$/.test(trimmed)) {
    return Number.parseInt(trimmed, 10);
  }
  return equateValue(source, trimmed);
}

function equateValue(source: string, name: string): number {
  return equateExpression(source, name)
    .split('+')
    .map((part) => parseNumber(source, part))
    .reduce((sum, value) => sum + value, 0);
}

function range(start: number, length: number): { start: number; end: number } {
  return { start, end: start + length };
}

function assertNoOverlap(a: { start: number; end: number }, b: { start: number; end: number }, name: string): void {
  assert.ok(a.end <= b.start || b.end <= a.start, `${name}: ${a.start.toString(16)}-${a.end.toString(16)} overlaps ${b.start.toString(16)}-${b.end.toString(16)}`);
}

test('shell RAM buffers do not overlap editor path workspace', () => {
  const editorPath = range(
    equateValue(equates, 'TECM8_EDITOR_NAV_PATH_BASE'),
    equateValue(equates, 'TECM8_EDITOR_NAV_PATH_LEN'),
  );
  const editorBackupPath = range(
    equateValue(equates, 'TECM8_EDITOR_NAV_BACKUP_PATH_BASE'),
    equateValue(equates, 'TECM8_EDITOR_NAV_PATH_LEN'),
  );
  const shellCommand = range(equateValue(ops, 'SHL_COMMAND_BUFFER'), equateValue(ops, 'SHL_COMMAND_CAPACITY'));
  const shellLine = range(equateValue(ops, 'SHL_LINE_BUFFER'), equateValue(ops, 'SHL_LINE_CAPACITY'));

  assertNoOverlap(shellLine, editorPath, 'shell line buffer vs editor path');
  assertNoOverlap(shellLine, editorBackupPath, 'shell line buffer vs editor backup path');
  assertNoOverlap(shellCommand, editorPath, 'shell command buffer vs editor path');
  assertNoOverlap(shellCommand, editorBackupPath, 'shell command buffer vs editor backup path');
  assertNoOverlap(shellLine, shellCommand, 'shell line buffer vs shell command buffer');
});
