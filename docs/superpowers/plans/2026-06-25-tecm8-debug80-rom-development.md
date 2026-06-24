# TECM8 Debug80 ROM Development Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make TECM8 a Debug80 TEC-1G custom project with project-owned monitor and expansion ROM source folders under `roms/`.

**Architecture:** Keep MON-3 as the active fixed monitor image for now, add a TECM8-owned expansion ROM through active source-backed `tec1g.romArtifacts`, and create an inactive monitor-replacement artifact for later. Preserve existing RAM-loaded targets and proof scripts.

**Tech Stack:** Debug80 `debug80.json`, TEC-1G `romHex`, `expansionRomHex`, and `romArtifacts`, AZM via `@jhlagado/azm/compile`, Node `--experimental-strip-types`, Z80 assembly.

---

## File Structure

- Modify `.gitignore`: remove the standalone `roms/` ignore and keep bundled
  `roms/tec1g/mon3/` materializations ignored.
- Modify `debug80.json`: rename the local profile to `tecm8`, keep MON-3 `romHex`, add generated `expansionRomHex`, add both ROM source folders to `sourceRoots`, and declare active expansion/inactive monitor `romArtifacts`.
- Create `roms/tec1g/tecm8/monitor/monitor.asm`: future monitor replacement scaffold assembled at `0xC000`.
- Create `roms/tec1g/tecm8/expansion/expansion.asm`: first expansion ROM scaffold assembled at `0x8000`.
- Create `tools/build-monitor-rom.ts`: build monitor scaffold to `roms/.../monitor.bin` and `build/roms/.../monitor.d8.json`.
- Create `tools/build-expansion-rom.ts`: build expansion scaffold to `roms/.../expansion.bin` and `build/roms/.../expansion.d8.json`.
- Modify `package.json`: add `rom:monitor`, `rom:expansion`, and `rom:check`.
- Modify `README.md`: document RAM-loaded and ROM-development modes.

---

### Task 1: Stop Ignoring ROM Source

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Verify current ignore**

Run:

```bash
rg -n '^roms/$' .gitignore
```

Expected: one match.

- [ ] **Step 2: Remove the broad ignore and keep MON-3 materializations local**

```text
remove: roms/
keep/add: roms/tec1g/mon3/
```

Keep `build/`, `out/`, `dist/`, generated demo artifacts, and OS/editor ignores.

- [ ] **Step 3: Verify `roms/` is trackable**

Run:

```bash
git check-ignore -v roms/tec1g/tecm8/monitor/monitor.asm roms/tec1g/tecm8/expansion/expansion.asm || true
```

Expected: no output.

---

### Task 2: Add ROM Source Scaffolds

**Files:**
- Create: `roms/tec1g/tecm8/monitor/monitor.asm`
- Create: `roms/tec1g/tecm8/expansion/expansion.asm`

- [ ] **Step 1: Create monitor source**

```asm
; TECM8 monitor ROM scaffold.
;
; MON-3 remains the active fixed monitor ROM for now. This source is where the
; future TECM8 monitor replacement will grow.

        .org    0xC000

TECM8_MONITOR_VERSION          .equ    0x01

@Tecm8MonitorEntry:
        JP      Tecm8MonitorHold

@Tecm8MonitorInfo:
        .db     "T","M","8",TECM8_MONITOR_VERSION

Tecm8MonitorHold:
        JP      Tecm8MonitorHold
```

- [ ] **Step 2: Create expansion source**

```asm
; TECM8 expansion ROM bank 0.
;
; This project-owned image is loaded into the TEC-1G expansion window while
; MON-3 remains the fixed monitor ROM.

        .org    0x8000

TECM8_EXPANSION_VERSION        .equ    0x01

@Tecm8ExpansionEntry:
        RET

@Tecm8ExpansionInfo:
        .db     "T","M","8",TECM8_EXPANSION_VERSION
```

---

### Task 3: Add ROM Build Scripts

**Files:**
- Create: `tools/build-monitor-rom.ts`
- Create: `tools/build-expansion-rom.ts`
- Modify: `package.json`

- [ ] **Step 1: Create `tools/build-monitor-rom.ts`**

Use the same shape as `tools/build-keyboard-tester.ts`, with:

```ts
const SOURCE_FILE = resolve(TECM8_ROOT, 'roms/tec1g/tecm8/monitor/monitor.asm');
const PROJECT_BIN_PATH = resolve(TECM8_ROOT, 'roms/tec1g/tecm8/monitor/monitor.bin');
const BUILD_BIN_PATH = resolve(TECM8_ROOT, 'build/roms/tec1g/tecm8/monitor/monitor.bin');
const BUILD_D8_PATH = resolve(TECM8_ROOT, 'build/roms/tec1g/tecm8/monitor/monitor.d8.json');
const ROM_START = 0xC000;
const ROM_BYTES = 16 * 1024;
```

Compile with:

```ts
await compile(SOURCE_FILE, {
  emitBin: true,
  emitD8m: true,
  outputType: 'bin',
  sourceRoot: TECM8_ROOT,
  d8mInputs: { bin: 'roms/tec1g/tecm8/monitor/monitor.bin' },
}, { formats: defaultFormatWriters });
```

Write the emitted bin to both `PROJECT_BIN_PATH` and `BUILD_BIN_PATH`, and write
the D8 JSON to `BUILD_D8_PATH`.

- [ ] **Step 2: Create `tools/build-expansion-rom.ts`**

Use the same script shape, with:

```ts
const SOURCE_FILE = resolve(TECM8_ROOT, 'roms/tec1g/tecm8/expansion/expansion.asm');
const PROJECT_BIN_PATH = resolve(TECM8_ROOT, 'roms/tec1g/tecm8/expansion/expansion.bin');
const BUILD_BIN_PATH = resolve(TECM8_ROOT, 'build/roms/tec1g/tecm8/expansion/expansion.bin');
const BUILD_D8_PATH = resolve(TECM8_ROOT, 'build/roms/tec1g/tecm8/expansion/expansion.d8.json');
const ROM_START = 0x8000;
const ROM_BANK_BYTES = 16 * 1024;
const ROM_BYTES = 32 * 1024;
```

Use `d8mInputs: { bin: 'roms/tec1g/tecm8/expansion/expansion.bin' }`.

- [ ] **Step 3: Add npm scripts**

Add:

```json
"rom:monitor": "node --experimental-strip-types tools/build-monitor-rom.ts",
"rom:expansion": "node --experimental-strip-types tools/build-expansion-rom.ts",
"rom:check": "npm run rom:monitor && npm run rom:expansion"
```

- [ ] **Step 4: Verify builds**

Run:

```bash
npm run rom:check
```

Expected: both scripts emit JSON with `"result": "ok"`.

---

### Task 4: Update Debug80 Config

**Files:**
- Modify: `debug80.json`

- [ ] **Step 1: Rename profile**

Set:

```json
"defaultProfile": "tecm8"
```

Replace profile key `mon3` with `tecm8`, preserving the MON-3 bundled asset
references.

- [ ] **Step 2: Update both targets**

For `main` and `keyboard-tester.main`:

```json
"profile": "tecm8",
"sourceRoots": [
  "src",
  "roms/tec1g/mon3",
  "roms/tec1g/tecm8/monitor",
  "roms/tec1g/tecm8/expansion"
]
```

Inside each `tec1g` block, keep:

```json
"romHex": "roms/tec1g/mon3/mon3.bin"
```

and add:

```json
"expansionRomHex": "build/roms/tec1g/tecm8/expansion/expansion.bin",
"romArtifacts": [
  {
    "id": "tecm8-expansion",
    "role": "expansion",
    "sourceFile": "roms/tec1g/tecm8/expansion/expansion.asm",
    "outputBin": "build/roms/tec1g/tecm8/expansion/expansion.bin",
    "outputDebugMap": "build/roms/tec1g/tecm8/expansion/expansion.d8.json",
    "windowAddress": 32768,
    "windowSize": 16384,
    "imageSize": 32768,
    "bankSize": 16384,
    "bankCount": 2
  },
  {
    "id": "tecm8-monitor",
    "role": "monitor",
    "active": false,
    "sourceFile": "roms/tec1g/tecm8/monitor/monitor.asm",
    "outputBin": "build/roms/tec1g/tecm8/monitor/monitor.bin",
    "outputDebugMap": "build/roms/tec1g/tecm8/monitor/monitor.d8.json",
    "address": 49152,
    "size": 16384
  }
]
```

- [ ] **Step 3: Validate JSON**

Run:

```bash
node -e "JSON.parse(require('fs').readFileSync('debug80.json', 'utf8')); console.log('ok')"
```

Expected: `ok`.

---

### Task 5: Document The Workflow

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add a Debug80 development modes section**

Add:

```markdown
## Debug80 Development Modes

TECM8 currently has two Debug80 workflows.

The RAM-loaded workflow remains the fast proof and live-editor path. Debug80
assembles `src/main.asm` into `build/main.bin`, loads it at `0x4000`, and runs
it with MON-3 providing storage, keyboard, and display services.

The ROM-development workflow keeps MON-3 as the active fixed monitor ROM for
now and adds project-owned TECM8 ROM source under `roms/tec1g/tecm8/`. Build
the ROM artifacts with:

```text
npm run rom:check
```

Debug80 builds the active expansion `tec1g.romArtifacts` entry, loads
`build/roms/tec1g/tecm8/expansion/expansion.bin` through `tec1g.expansionRomHex`,
and makes it available through the TEC-1G banked expansion window at
`0x8000-0xBFFF`. The monitor source is present as an inactive artifact for
development, but `tec1g.romHex` continues to point at MON-3 until the TECM8
monitor can boot.
```

---

### Task 6: Verification

**Files:**
- No direct edits.

- [ ] **Step 1: Run verification**

Run:

```bash
npm run rom:check
npm run typecheck
npm test
npm run z80:size
```

Expected: all commands exit 0.

- [ ] **Step 2: Check git status**

Run:

```bash
git status --short
```

Expected changed files include `.gitignore`, `README.md`, `debug80.json`,
`package.json`, the two ROM source folders, the two ROM build scripts, and the
new generated project ROM `.bin` files under `roms/tec1g/tecm8/`.
