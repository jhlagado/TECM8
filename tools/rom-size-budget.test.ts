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
  assert.equal(pkg.scripts['rom:size:delta'], 'node --experimental-strip-types tools/check-rom-size-delta.ts');
  assert.match(pkg.scripts.check, /npm run rom:size:check/);
});

test('ROM size budget gate defines per-bank hard budgets and total expansion guard', () => {
  const checker = readFileSync(resolve(root, 'tools/check-rom-size-budget.ts'), 'utf8');

  assert.match(checker, /const monitorBytes = 0x4000/);
  assert.match(checker, /const totalExpansionHardSpan = 0x10000/);
  assert.match(checker, /Shell, launcher, registry/);
  assert.match(checker, /VDU\/TMS9918 boundary/);
  assert.match(checker, /TEC-FS boundary and block mapper/);
  assert.match(checker, /Phase-one self-hosted assembler/);
  assert.match(checker, /Validated loader and runner/);
  assert.match(checker, /exceeds hard budget/);
  assert.match(checker, /exceeds soft budget/);
  assert.match(checker, /function printSummary/);
  assert.match(checker, /function validateBudget/);
  assert.match(checker, /function softFree/);
  assert.match(checker, /--json/);
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
  assert.match(output, /bank 0 Shell, launcher, registry: occupied=\d+ span=\d+ soft=2048 softFree=\d+ hard=4096/);
  assert.match(output, /bank 8 Validated loader and runner:/);
  assert.match(output, /expansion total: occupied=\d+ span=\d+ soft=32768 softFree=\d+ hard=65536/);
});

test('ROM size checker can emit machine-readable JSON for delta tooling', () => {
  execFileSync('npm', ['run', 'rom:check'], {
    cwd: root,
    encoding: 'utf8',
  });
  const output = execFileSync('node', ['--experimental-strip-types', 'tools/check-rom-size-budget.ts', '--json'], {
    cwd: root,
    encoding: 'utf8',
  });
  const report = JSON.parse(output);

  assert.equal(report.monitor.span, 16384);
  assert.equal(report.expansionTotal.hardSpan, 65536);
  assert.equal(report.banks.length, 9);
  assert.equal(report.banks[0].role, 'Shell, launcher, registry');
});

test('ROM size delta tool compares current footprint with the checked-in baseline', () => {
  const baseline = JSON.parse(readFileSync(resolve(root, 'docs/metrics/rom-size-baseline.json'), 'utf8'));
  const deltaTool = readFileSync(resolve(root, 'tools/check-rom-size-delta.ts'), 'utf8');

  assert.equal(baseline.schema, 'tecm8-rom-size-baseline-v1');
  assert.equal(baseline.monitor.span, 16384);
  assert.equal(baseline.expansionTotal.hardSpan, 65536);
  assert.equal(baseline.banks.length, 9);
  assert.match(deltaTool, /docs\/metrics\/rom-size-baseline\.json/);
  assert.match(deltaTool, /baseline role mismatch/);
  assert.match(deltaTool, /# TecMate ROM Size Delta/);
  assert.match(deltaTool, /Occupied Delta/);
});

test('ROM size baseline matches the generated footprint report exactly', () => {
  execFileSync('npm', ['run', 'rom:check'], {
    cwd: root,
    encoding: 'utf8',
  });
  const baseline = JSON.parse(readFileSync(resolve(root, 'docs/metrics/rom-size-baseline.json'), 'utf8'));
  const output = execFileSync('node', ['--experimental-strip-types', 'tools/check-rom-size-budget.ts', '--json'], {
    cwd: root,
    encoding: 'utf8',
  });
  const report = JSON.parse(output);

  assert.deepEqual(
    {
      monitor: baseline.monitor,
      banks: baseline.banks,
      expansionTotal: baseline.expansionTotal,
    },
    report,
  );
});

test('ROM size delta command prints span and occupied deltas', () => {
  const output = execFileSync('npm', ['run', 'rom:size:delta'], {
    cwd: root,
    encoding: 'utf8',
  });

  assert.match(output, /# TecMate ROM Size Delta/);
  assert.match(output, /\| Area \| Current Span \| Span Delta \| Current Occupied \| Occupied Delta \|/);
  assert.match(output, /\| Fixed monitor \| 16384 \| 0 \| 9007 \| 0 \|/);
  assert.match(output, /\| Expansion total \| \d+ \| [-+0-9]+ \| \d+ \| [-+0-9]+ \|/);
  assert.match(output, /\| Bank 0 Shell, launcher, registry \|/);
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
  assert.match(output, /\| Bank \| Role \| Span \| Soft \| Soft Free \| Hard \| Free \| Status \|/);
  assert.match(output, /\| 0 \| Shell, launcher, registry \| \d+ \| 2048 \| \d+ \| 4096 \|/);
  assert.match(output, /\| 8 \| Validated loader and runner \|/);
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
  assert.match(doc, /npm run checkpoint:tecmate-rom/);
  assert.match(doc, /preferred copy\/paste\s+checkpoint because it shows both sides of the MVP question/);
  assert.match(doc, /what a human can\s+see, and how many bytes the current ROMs occupy/);
  assert.match(doc, /## Required Size Review/);
  assert.match(doc, /Every meaningful ROM-facing development increment must include a binary-size\s+review before it is considered complete/);
  assert.match(doc, /Run `npm run checkpoint:tecmate-rom`, or `npm run rom:size:summary` when the\s+increment is size-only/);
  assert.match(doc, /Record the fixed monitor span/);
  assert.match(doc, /Record the expansion total high-water span against the hard budget/);
  assert.match(doc, /occupied bytes as secondary context/);
  assert.match(doc, /Compare the result with the last pushed baseline or the pre-change branch\s+result/);
  assert.match(doc, /Record any changed per-bank spans and deltas/);
  assert.match(doc, /If the command fails, the increment is not complete/);
  assert.match(doc, /any fixed-ROM growth must be paired with an\s+identified removal, relocation, or split plan/);
  assert.match(doc, /Every meaningful ROM-facing increment should publish the current checkpoint from\s+`npm run checkpoint:tecmate-rom` in the review notes, commit summary, or handoff\s+message/);
  assert.match(doc, /Size-only increments may use `npm run rom:size:summary` instead/);
  assert.match(doc, /keeps both visible behavior and growth visible/);
  assert.match(doc, /editor, TEC-FS, and\s+assembler/);
  assert.match(doc, /prevents GLCD or optional tooling from\s+quietly consuming/);
  assert.match(doc, /Bank 0 must not become a junk drawer/);
  assert.match(doc, /Shell command results must stay byte-sized first/);
  assert.match(doc, /short VDU labels such as `OK`, `FILE`, or `UNSUP`/);
  assert.match(doc, /rich diagnostic text, formatted listings, help screens, and tool-specific UI\s+belong in tool banks or later overlays/);
  assert.match(doc, /`SHL_PARAM_COMMAND_RESULT_LO\/HI` is the\s+preferred Bank 0 contract/);
});

test('ROM size budget policy constrains profile and runtime growth', () => {
  const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-rom-size-budget.md'), 'utf8');

  assert.match(doc, /## Profile And Runtime Budget Policy/);
  assert.match(doc, /profile support remains subordinate to Tier 1/);
  assert.match(doc, /A game profile is a proving case/);
  assert.match(doc, /generated structure bytes/);
  assert.match(doc, /user behaviour code bytes where known/);
  assert.match(doc, /resource bytes/);
  assert.match(doc, /runtime helper bytes/);
  assert.match(doc, /package\/metadata overhead/);
  assert.match(doc, /final binary or bank span/);
  assert.match(doc, /Bank 0 may know how to dispatch `profile` or\s+`game` commands later/);
  assert.match(doc, /should not carry the profile preprocessor, game\s+runtime, resource packer, or debugger UI/);
  assert.match(doc, /Generated assembly should be measured like hand-written assembly/);
});
