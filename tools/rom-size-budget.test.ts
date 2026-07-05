const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { execFileSync } = require('node:child_process');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('ROM size budget gate is wired into package scripts', () => {
  const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));

  assert.equal(pkg.scripts['rom:size:check'], 'npm run rom:check && node --experimental-strip-types tools/check-rom-size-budget.ts');
  assert.equal(pkg.scripts['rom:size:summary'], 'npm run rom:check && node --experimental-strip-types tools/check-rom-size-budget.ts --summary');
  assert.match(pkg.scripts.check, /npm run rom:size:check/);
});

test('ROM size budget gate defines per-bank hard budgets and total expansion guard', () => {
  const checker = readFileSync(resolve(root, 'tools/check-rom-size-budget.ts'), 'utf8');

  assert.match(checker, /const monitorBytes = 0x4000/);
  assert.match(checker, /const totalExpansionHardSpan = 0x10000/);
  assert.match(checker, /Shell, launcher, registry/);
  assert.match(checker, /VDU\/TMS9918 boundary/);
  assert.match(checker, /TEC-FS boundary and block mapper/);
  assert.match(checker, /Assembler skeleton/);
  assert.match(checker, /Run skeleton/);
  assert.match(checker, /exceeds hard budget/);
  assert.match(checker, /exceeds soft budget/);
  assert.match(checker, /function printSummary/);
  assert.match(checker, /function validateBudget/);
  assert.match(checker, /# TecMate ROM Footprint/);
});

test('ROM size budget checker executes against current D8 artifacts', () => {
  execFileSync('npm', ['run', 'rom:check'], {
    cwd: root,
    encoding: 'utf8',
  });
  const output = execFileSync('node', ['--experimental-strip-types', 'tools/check-rom-size-budget.ts'], {
    cwd: root,
    encoding: 'utf8',
  });

  assert.match(output, /monitor span=16384\/16384/);
  assert.match(output, /bank 0 Shell, launcher, registry:/);
  assert.match(output, /bank 8 Run skeleton:/);
  assert.match(output, /expansion total: occupied=/);
});

test('ROM size budget checker can print a compact footprint summary', () => {
  execFileSync('npm', ['run', 'rom:check'], {
    cwd: root,
    encoding: 'utf8',
  });
  const output = execFileSync('node', ['--experimental-strip-types', 'tools/check-rom-size-budget.ts', '--summary'], {
    cwd: root,
    encoding: 'utf8',
  });

  assert.match(output, /# TecMate ROM Footprint/);
  assert.match(output, /Fixed monitor span: 16384\/16384 bytes/);
  assert.match(output, /Expansion total span: \d+\/65536 bytes hard budget/);
  assert.match(output, /\| Bank \| Role \| Span \| Soft \| Hard \| Free \| Status \|/);
  assert.match(output, /\| 0 \| Shell, launcher, registry \|/);
  assert.match(output, /\| 8 \| Run skeleton \|/);
});

test('ROM size budget checker clamps expansion measurements to the visible bank window', () => {
  const checker = readFileSync(resolve(root, 'tools/check-rom-size-budget.ts'), 'utf8');

  assert.match(checker, /function expansionWindowSegments/);
  assert.match(checker, /Math\.max\(segment\.start, 0x8000\)/);
  assert.match(checker, /Math\.min\(segment\.end, 0xc000\)/);
  assert.doesNotMatch(checker, /d8\.segments\.filter\(\(segment\) => segment\.end > 0x8000 && segment\.start < 0xc000\);\s*const measurement = spanForSegments\(visibleSegments\)/);
});

test('ROM size budget policy documents the smallest viable system rule', () => {
  const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-rom-size-budget.md'), 'utf8');

  assert.match(doc, /smallest viable TecMate system/);
  assert.match(doc, /Tier 0/);
  assert.match(doc, /Tier 1/);
  assert.match(doc, /Tier 2/);
  assert.match(doc, /Tier 3/);
  assert.match(doc, /npm run rom:size:check/);
  assert.match(doc, /npm run rom:size:summary/);
  assert.match(doc, /Every meaningful ROM-facing increment should publish the current footprint from\s+`npm run rom:size:summary` in the review notes, commit summary, or handoff\s+message/);
  assert.match(doc, /editor, TEC-FS, and assembler/);
  assert.match(doc, /prevents GLCD or optional tooling from quietly consuming/);
  assert.match(doc, /Bank 0 must not become a junk drawer/);
});
