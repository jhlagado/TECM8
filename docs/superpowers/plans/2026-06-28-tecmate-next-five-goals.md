# TecMate Next Five Goals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the next five TecMate ROM/platform increments with review, verification, commits, and pushes between each increment.

**Architecture:** Keep the fixed monitor small and stable, with TecMate behaviour moving into the banked expansion ROM and documented/proved contracts between those regions. Each increment adds one concrete contract, proof, or measurement so later ROM work can build forward without guessing.

**Tech Stack:** Z80 assembly assembled by AZM, Debug80 TEC-1G runtime proof runners, Node test runner with `--experimental-strip-types`, TypeScript tooling.

---

### Task 1: Shell Exit Contract

**Files:**
- Modify: `docs/mon3/tecmate-monitor-launch-contract.md`
- Create: `tools/tecmate-shell-exit-contract.test.ts`
- Possibly modify: `package.json`

- [ ] Document that the current menu path enters TecMate through `runRoutine`, which pushes `softBoot`.
- [ ] State that current bank-0 exit is a plain `ret` to monitor soft boot, not a far return.
- [ ] Add tests that tie the wording to `runRoutine`, `launchTecMate`, and the monitor-launch proof.
- [ ] Run `npm test -- tools/tecmate-shell-exit-contract.test.ts`, `npm run proof:tecmate-monitor-launch`, `npm run typecheck`, and `git diff --check`.
- [ ] Request high-effort review, fix important findings, re-review, commit, and push.

### Task 2: Bank-0 Bootstrap Skeleton

**Files:**
- Modify: `roms/tec1g/tecm8/expansion/bank0.asm`
- Modify: `roms/tec1g/tecm8/expansion/bank_ops.asmi`
- Modify or create: proof/test files under `tools/` and `proofs/`

- [ ] Replace the ad hoc bank-0 entry proof chain with named bootstrap phases.
- [ ] Preserve current service-call proof markers so existing proofs remain meaningful.
- [ ] Add or update tests proving the bootstrap order: VDU init, TEC-FS mount, input placeholder, shell placeholder.
- [ ] Run ROM build, relevant bank proofs, typecheck, tests, and `git diff --check`.
- [ ] Review, fix, re-review, commit, and push.

### Task 3: TEC-FS Runtime Volume Selection

**Files:**
- Modify: `roms/tec1g/tecm8/expansion/bank2.asm`
- Modify: `roms/tec1g/tecm8/expansion/bank_ops.asmi`
- Modify: `tools/run-tecfs-bank-proof.ts`
- Modify: TEC-FS bank tests/docs as needed

- [ ] Add a runtime select-volume service that validates user volumes and updates active volume state.
- [ ] Prove translation uses the selected volume and rejects invalid volume numbers.
- [ ] Keep 30 user volumes plus one spare volume semantics.
- [ ] Run TEC-FS proof, ROM build, typecheck, tests, and `git diff --check`.
- [ ] Review, fix, re-review, commit, and push.

### Task 4: TMS9918/VDU Text Console Contract

**Files:**
- Modify: `docs/mon3/tecmate-banked-service-abi.md`
- Modify: `roms/tec1g/tecm8/expansion/bank1.asm`
- Modify: `roms/tec1g/tecm8/expansion/bank_ops.asmi`
- Modify: `tools/run-tms9918-bank-proof.ts`

- [ ] Define the minimal text console API: init, clear, set cursor, put char, and status/error slots.
- [ ] Keep calls banked behind the existing ABI.
- [ ] Prove parameter publication and service results.
- [ ] Run TMS9918 proof, ROM build, typecheck, tests, and `git diff --check`.
- [ ] Review, fix, re-review, commit, and push.

### Task 5: Monitor ROM Space Map Against Fixed-ROM Services

**Files:**
- Modify: `docs/mon3/tecmate-rom-space-map.md`
- Modify or create: ROM-space map tests under `tools/`

- [ ] Update the space map to distinguish fixed-ROM requirements from expansion-resident services.
- [ ] Keep GLCD low priority and only mention it as a future containment issue if it blocks space.
- [ ] Identify PATA/FAT32 replacement pressure in favour of TEC-FS without changing code in this task.
- [ ] Run the ROM-space tests, MON3 inventory/split checks, typecheck, and `git diff --check`.
- [ ] Review, fix, re-review, commit, and push.
