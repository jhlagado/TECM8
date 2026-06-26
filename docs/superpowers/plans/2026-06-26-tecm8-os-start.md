# TECM8 OS Start Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start the ROM-based TECM8 operating-system track by pausing editor feature growth, building the first expansion-ROM libraries and smoke program, starting VDU and TEC-FS foundations, and clearing enough fixed-ROM space for reliable bank switching.

**Architecture:** MON3-derived fixed ROM remains the compatibility and BIOS layer at `C000h-FFFFh`. TECM8 grows in the banked expansion ROM window at `8000h-BFFFh`, using a 144K backing image with two legacy expand pages plus seven additional 16K TECM8 slots. Each slot assembles for the visible address range at `0x8000`. The first implementation keeps the existing editor as reference code but shifts active development toward reusable ROM services and a tiny launchable program.

**Tech Stack:** Z80 assembly, AZM, Debug80 `romArtifacts`, TEC-1G fixed monitor ROM, TEC-1G banked expansion ROM, TMS9918-style VDU target, TEC-FS storage design, Node-based build/proof tooling.

---

## File Structure

- Modify `docs/roadmap.md`: mark editor feature work as paused and make the ROM-based OS track the active near-term roadmap.
- Modify `roms/tec1g/tecm8/expansion/expansion.asm`: replace the bare return stub with a bank manifest and a tiny launchable TECM8 program.
- Create `roms/tec1g/tecm8/expansion/bank_services.asmi`: shared constants for bank manifests, bank IDs, and fixed-ROM bank-call services.
- Create `roms/tec1g/tecm8/expansion/vdu_services.asm`: first VDU/TMS9918-facing service skeleton.
- Create `roms/tec1g/tecm8/expansion/tecfs_services.asm`: first TEC-FS-facing service skeleton and volume constants.
- Modify `roms/tec1g/tecm8/monitor/api_includes.asm`: reserve stable service numbers for bank select, bank call, and TECM8 launch.
- Modify `roms/tec1g/tecm8/monitor/monitor.asm`: add a small monitor-side TECM8 launch hook and fixed-ROM-owned bank-call routine.
- Modify `roms/tec1g/tecm8/monitor/rtc.asm`: prepare to split RTC service routines from interactive RTC setup UI.
- Modify `tools/build-expansion-rom.ts`: keep producing a nine-slot-compatible expansion artifact and verify size constraints.
- Add focused tests under `tools/` for expansion manifest shape, monitor service reservations, and generated ROM sizes.

## Pause Rule

The current RAM-loaded editor remains valuable but should be put on ice for this phase.

Allowed editor work:

- bug fixes that protect existing proofs
- changes needed to move editor code into a banked tool later
- documentation of editor service dependencies

Deferred editor work:

- new editor commands
- richer block operations
- shell polish
- assembler integration
- larger UI features

The aim is to stop growing the application until the ROM platform can carry it properly.

## Task 1: Roadmap Reframe

**Files:**
- Modify: `docs/roadmap.md`

- [ ] **Step 1: Add the active ROM-platform phase near the top of the roadmap**

Add this paragraph under the current active-track section:

```markdown
## Active Track: ROM-Based TECM8 OS Bootstrap

Editor feature work is paused while the project establishes the ROM platform
needed to host TECM8 as an operating environment. The active work is now the
fixed MON3-derived monitor ROM, the banked TECM8 expansion ROM, the first VDU
and TEC-FS libraries, and the bank-call mechanism that lets fixed ROM and
banked tools cooperate safely.
```

- [ ] **Step 2: Add the editor pause rule**

Add a short subsection matching the pause rule in this plan.

- [ ] **Step 3: Verify the roadmap text**

Run:

```bash
rg -n "ROM-Based TECM8 OS Bootstrap|Editor feature work is paused" docs/roadmap.md
```

Expected: both phrases are found.

- [ ] **Step 4: Commit**

Run:

```bash
git add docs/roadmap.md
git commit -m "docs: start TECM8 ROM OS track"
```

## Task 2: Expansion ROM Manifest And Tiny Program

**Files:**
- Modify: `roms/tec1g/tecm8/expansion/expansion.asm`
- Create: `roms/tec1g/tecm8/expansion/bank_services.asmi`
- Test: `tools/rom-development-config.test.ts`

- [ ] **Step 1: Add shared manifest constants**

Create `roms/tec1g/tecm8/expansion/bank_services.asmi`:

```asm
; TECM8 expansion ROM bank manifest and fixed-ROM service constants.

TECM8_BANK_ORIGIN              .equ    0x8000
TECM8_BANK_WINDOW_BYTES        .equ    0x4000

TECM8_BANK_MANIFEST            .equ    TECM8_BANK_ORIGIN
TECM8_BANK_SIGNATURE_0         .equ    "T"
TECM8_BANK_SIGNATURE_1         .equ    "M"
TECM8_BANK_SIGNATURE_2         .equ    "8"
TECM8_BANK_SIGNATURE_3         .equ    "B"
TECM8_BANK_MANIFEST_VERSION    .equ    0x01

TECM8_BANK_TYPE_FRONTEND       .equ    0x01
TECM8_BANK_TYPE_TOOL           .equ    0x02
TECM8_BANK_TYPE_LIBRARY        .equ    0x03

TECM8_BANK0_ID                 .equ    0x00
TECM8_BANK1_ID                 .equ    0x01
```

- [ ] **Step 2: Replace the expansion stub with a manifest and tiny entry**

Use this shape in `roms/tec1g/tecm8/expansion/expansion.asm`:

```asm
; TECM8 expansion ROM bank 0.
;
; First banked TECM8 program. It proves that the 8000h-BFFFh expansion window
; can expose a manifest and run a tiny program through MON3Lite.

        .include "bank_services.asmi"

        .org    TECM8_BANK_ORIGIN

@Tecm8BankManifest:
        .db     TECM8_BANK_SIGNATURE_0
        .db     TECM8_BANK_SIGNATURE_1
        .db     TECM8_BANK_SIGNATURE_2
        .db     TECM8_BANK_SIGNATURE_3
        .db     TECM8_BANK_MANIFEST_VERSION
        .db     TECM8_BANK0_ID
        .db     TECM8_BANK_TYPE_FRONTEND
        .db     0x00
        .dw     Tecm8ExpansionEntry
        .dw     Tecm8ExpansionName

@Tecm8ExpansionEntry:
        RET

@Tecm8ExpansionName:
        .db     "TECM8 BANK 0",0
```

- [ ] **Step 3: Add a manifest assertion test**

Extend `tools/rom-development-config.test.ts` with a test that reads
`roms/tec1g/tecm8/expansion/expansion.bin` after `npm run rom:expansion` and
asserts:

```ts
assert.equal(bin[0], 'T'.charCodeAt(0));
assert.equal(bin[1], 'M'.charCodeAt(0));
assert.equal(bin[2], '8'.charCodeAt(0));
assert.equal(bin[3], 'B'.charCodeAt(0));
assert.equal(bin[4], 0x01);
assert.equal(bin[5], 0x00);
```

- [ ] **Step 4: Verify**

Run:

```bash
npm run rom:expansion
npm test -- --test-name-pattern "ROM"
```

Expected: expansion ROM builds and ROM development tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add roms/tec1g/tecm8/expansion tools/rom-development-config.test.ts
git commit -m "feat: add TECM8 expansion bank manifest"
```

## Task 3: Fixed-ROM Bank Service Reservations

**Files:**
- Modify: `roms/tec1g/tecm8/monitor/api_includes.asm`
- Modify: `roms/tec1g/tecm8/monitor/monitor.asm`
- Test: `tools/rom-development-config.test.ts`

- [ ] **Step 1: Reserve API names**

Add service names for:

```text
Tecm8Launch
Tecm8GetBank
Tecm8SelectBank
Tecm8CallBank
Tecm8ReturnBank
```

The first implementation may point these at simple stubs, but the names and
reserved call numbers should be stable once added.

- [ ] **Step 2: Implement fixed-ROM-owned bank stubs**

Add monitor-side routines with these initial behaviours:

```text
Tecm8Launch     selects bank 0 and calls its manifest entry
Tecm8GetBank    returns the current bank byte from monitor RAM
Tecm8SelectBank records requested bank in monitor RAM and updates hardware later
Tecm8CallBank   saves current bank, selects target bank, calls target entry
Tecm8ReturnBank restores previous bank
```

For the first pass, hardware bank switching can be a named routine with one
implementation point. The important rule is that banked code calls fixed ROM;
banked code does not own the hardware latch.

- [ ] **Step 3: Define the first far-call convention**

Use this provisional calling convention for the first implementation:

```text
Tecm8FarJump
  Input:  B = target bank
          HL = target address in the 8000h-BFFFh window
  Action: discard the caller return address, select target bank, then JP (HL)
  Return: does not return

Tecm8FarCall
  Input:  B = target bank
          HL = target address in the 8000h-BFFFh window
  Action: save current bank, select target bank, call target address
  Return: target code RETs to fixed-ROM return trampoline; previous bank is
          restored before returning to the original caller
```

Do not use the Z80 `I` register for this ABI. It is the interrupt vector base
register and is a poor general-purpose bank parameter. Avoid `C` as the bank
register because MON3's existing `RST 10h` API uses `C` as the function index.
Using `B` keeps the call shape close to a long jump while leaving `DE`, `IX`,
and `IY` available for payload parameters.

The intended `RST 10h` call shape is:

```asm
        ld      c,Tecm8FarCall_
        ld      b,target_bank
        ld      hl,target_entry
        rst     10h
```

Because `Tecm8FarJump` is reached through the monitor API path but does not
return, it must remove the unused return address from the stack before jumping.
The least destructive form is:

```asm
Tecm8FarJump:
        inc     sp
        inc     sp
        ld      a,b
        call    Tecm8SelectBankRaw
        jp      (hl)
```

This leaves the caller's stack as if the API call had returned, then transfers
control permanently to the selected bank.

The fixed-ROM trampoline can use the normal Z80 stack so nested far calls remain
possible:

```asm
; Concept only. Final code must match actual monitor RAM and bank latch names.
; Input: B = target bank, HL = target entry
Tecm8FarCall:
        ld      a,(TECM8_CURRENT_BANK)
        push    af
        ld      de,Tecm8FarReturn
        push    de
        ld      a,b
        call    Tecm8SelectBankRaw
        jp      (hl)

Tecm8FarReturn:
        pop     af
        call    Tecm8SelectBankRaw
        ret
```

This stack shape means the banked target simply executes `RET`. It returns into
fixed ROM, fixed ROM restores the previous bank, and then fixed ROM returns to
the original caller. A far jump is separate because it intentionally does not
restore the previous bank.

- [ ] **Step 4: Add a ROM test for service names**

Extend the ROM-development test to assert that the monitor debug map contains
the new service labels.

- [ ] **Step 5: Verify**

Run:

```bash
npm run rom:monitor
npm test -- --test-name-pattern "ROM"
```

Expected: monitor builds and the new service labels appear in the debug map.

- [ ] **Step 6: Commit**

Run:

```bash
git add roms/tec1g/tecm8/monitor tools/rom-development-config.test.ts
git commit -m "feat: reserve TECM8 bank services"
```

## Task 4: First VDU/TMS9918 Library Skeleton

**Files:**
- Create: `roms/tec1g/tecm8/expansion/vdu_services.asm`
- Modify: `roms/tec1g/tecm8/expansion/expansion.asm`
- Test: `tools/rom-development-config.test.ts`

- [ ] **Step 1: Create the VDU service skeleton**

Create `roms/tec1g/tecm8/expansion/vdu_services.asm`:

```asm
; TECM8 VDU/TMS9918 service skeleton.
;
; These routines are the first expansion-ROM display profile. They deliberately
; expose intent before binding the code to final TMS9918 port details.

@Tecm8VduInit:
        RET

@Tecm8VduClear:
        RET

@Tecm8VduSetCursor:
        RET

@Tecm8VduWriteChar:
        RET

@Tecm8VduWriteString:
        RET
```

- [ ] **Step 2: Include VDU services from the expansion ROM**

Add:

```asm
        .include "vdu_services.asm"
```

after the bank-0 name string in `expansion.asm`.

- [ ] **Step 3: Add symbol tests**

Assert the expansion debug map contains:

```text
Tecm8VduInit
Tecm8VduClear
Tecm8VduSetCursor
Tecm8VduWriteChar
Tecm8VduWriteString
```

- [ ] **Step 4: Verify**

Run:

```bash
npm run rom:expansion
npm test -- --test-name-pattern "ROM"
```

Expected: expansion ROM builds and VDU symbols are present.

- [ ] **Step 5: Commit**

Run:

```bash
git add roms/tec1g/tecm8/expansion tools/rom-development-config.test.ts
git commit -m "feat: add VDU service skeleton"
```

## Task 5: First TEC-FS Library Skeleton

**Files:**
- Create: `roms/tec1g/tecm8/expansion/tecfs_services.asm`
- Modify: `roms/tec1g/tecm8/expansion/expansion.asm`
- Test: `tools/rom-development-config.test.ts`

- [ ] **Step 1: Create TEC-FS service constants and stubs**

Create `roms/tec1g/tecm8/expansion/tecfs_services.asm`:

```asm
; TECM8 TEC-FS service skeleton.
;
; The standard TEC-FS image volume is 128 MiB with 4 KiB allocation blocks.

TECM8_TECFS_SECTOR_BYTES       .equ    512
TECM8_TECFS_BLOCK_SECTORS      .equ    8
TECM8_TECFS_BLOCK_BYTES        .equ    4096
TECM8_TECFS_IMAGE_SECTORS      .equ    0x40000
TECM8_TECFS_USER_VOLUME_COUNT  .equ    30
TECM8_TECFS_WORK_VOLUME        .equ    30

@Tecm8TecfsInit:
        RET

@Tecm8TecfsSelectVolume:
        RET

@Tecm8TecfsReadSector:
        RET

@Tecm8TecfsWriteSector:
        RET
```

- [ ] **Step 2: Include TEC-FS services from the expansion ROM**

Add:

```asm
        .include "tecfs_services.asm"
```

after the VDU include in `expansion.asm`.

- [ ] **Step 3: Add symbol and constant tests**

Assert the expansion debug map contains:

```text
Tecm8TecfsInit
Tecm8TecfsSelectVolume
Tecm8TecfsReadSector
Tecm8TecfsWriteSector
```

Assert the source contains:

```text
TECM8_TECFS_IMAGE_SECTORS      .equ    0x40000
TECM8_TECFS_USER_VOLUME_COUNT  .equ    30
TECM8_TECFS_WORK_VOLUME        .equ    30
```

- [ ] **Step 4: Verify**

Run:

```bash
npm run rom:expansion
npm test -- --test-name-pattern "ROM"
```

Expected: expansion ROM builds and TEC-FS symbols/constants are present.

- [ ] **Step 5: Commit**

Run:

```bash
git add roms/tec1g/tecm8/expansion tools/rom-development-config.test.ts
git commit -m "feat: add TEC-FS service skeleton"
```

## Task 6: RTC Fixed-ROM Reduction Plan

**Files:**
- Modify: `docs/mon3/core-and-auxiliary-services.md`
- Modify: `docs/mon3/decomposition.md`
- Modify later: `roms/tec1g/tecm8/monitor/rtc.asm`

- [ ] **Step 1: Document the RTC split**

Update the RTC sections to state:

```text
Keep in fixed ROM:
- detect DS1302
- get/set time
- get/set date
- get/set day
- get/set 12/24-hour mode
- raw RTC RAM byte read/write
- checksum helper if MON3 PRAM persistence remains

Move to expansion ROM:
- interactive clock setup UI
- LCD help text
- PRAM viewer
- formatted display screens
```

- [ ] **Step 2: Add a source marker before `RTCSetup`**

Add a comment in `rtc.asm` immediately above `RTCSetup`:

```asm
; TECM8 split target: this interactive RTC setup application should move out
; of fixed ROM once the expansion-ROM tool framework is active. Keep the compact
; DS1302 service routines resident.
```

- [ ] **Step 3: Verify**

Run:

```bash
npm run rom:monitor
git diff --check -- docs/mon3/core-and-auxiliary-services.md docs/mon3/decomposition.md roms/tec1g/tecm8/monitor/rtc.asm
```

Expected: monitor still builds and the diff has no whitespace errors.

- [ ] **Step 4: Commit**

Run:

```bash
git add docs/mon3/core-and-auxiliary-services.md docs/mon3/decomposition.md roms/tec1g/tecm8/monitor/rtc.asm
git commit -m "docs: mark RTC UI split"
```

## Task 7: GLCD And Storage Reduction Queue

**Files:**
- Modify: `docs/mon3/mon3-light-platform-direction.md`
- Modify: `docs/mon3/core-and-auxiliary-services.md`
- Modify later: `roms/tec1g/tecm8/monitor/glcd_library.asm`
- Modify later: `roms/tec1g/tecm8/monitor/pata_fat32.asm`

- [ ] **Step 1: Add the first reduction order**

Document this order:

```text
1. Stop adding GLCD fixed-ROM code.
2. Move GLCD banner/assets first.
3. Keep compact GLCD primitives only where they serve BIOS/display services.
4. Remove PATA from the standard TECM8 monitor profile.
5. Preserve SD sector I/O.
6. Replace FAT32 workflows with TEC-FS services and expansion-ROM tools.
```

- [ ] **Step 2: Verify**

Run:

```bash
git diff --check -- docs/mon3/mon3-light-platform-direction.md docs/mon3/core-and-auxiliary-services.md
```

Expected: no whitespace errors.

- [ ] **Step 3: Commit**

Run:

```bash
git add docs/mon3/mon3-light-platform-direction.md docs/mon3/core-and-auxiliary-services.md
git commit -m "docs: queue fixed ROM reductions"
```

## Task 8: Whole-Platform Checkpoint

**Files:**
- Modify as needed: `CHANGELOG.md`

- [ ] **Step 1: Run the ROM checks**

Run:

```bash
npm run rom:check
```

Expected: monitor and expansion ROM artifacts build.

- [ ] **Step 2: Run focused tests**

Run:

```bash
npm test -- --test-name-pattern "ROM"
```

Expected: ROM-development tests pass.

- [ ] **Step 3: Run the full check if the focused tests pass**

Run:

```bash
npm run check
```

Expected: existing project checks pass. If this is too slow for the immediate
iteration, record the skipped full check in the final status and run it before
merging.

- [ ] **Step 4: Record the checkpoint**

Add a short `CHANGELOG.md` entry:

```markdown
- Started the TECM8 ROM-based OS bootstrap track: expansion bank manifest,
  fixed-ROM bank-service reservations, VDU and TEC-FS service skeletons, and
  first MON3 reduction queue.
```

- [ ] **Step 5: Commit**

Run:

```bash
git add CHANGELOG.md
git commit -m "docs: record TECM8 OS bootstrap checkpoint"
```

## Self-Review

Spec coverage:

- Editor/application work is paused by Task 1.
- First small expansion-ROM program is covered by Task 2.
- Bank-switching and long-call groundwork is covered by Task 3.
- VDU/TMS9918 work starts in Task 4.
- TEC-FS work starts in Task 5.
- Monitor space recovery starts with RTC UI split in Task 6.
- GLCD and storage reduction order is captured in Task 7.
- Build/test checkpoint is covered in Task 8.

No task requires the final editor, assembler, BASIC, debugger, or full TEC-FS
implementation. This plan creates the platform spine first.
