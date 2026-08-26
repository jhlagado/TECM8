# Register Contract Policy

Debug80 now accepts AZM register contract policy configuration. This lets TECM8
turn contracts on for new code while treating imported MON3 code as a gradual
cleanup surface.

The policy shape is:

```json
{
  "azm": {
    "registerContracts": "strict",
    "registerContractsPolicy": {
      "strict": ["src/**/*.asm"],
      "audit": ["roms/tec1g/tecm8/monitor/**/*.asm"],
      "off": ["vendor/**/*.asm"]
    },
    "registerContractsProfile": "mon3",
    "emitRegisterReport": true
  }
}
```

Policy entries are AZM glob patterns. The available policy buckets are
`strict`, `audit`, and `off`. More specific matches win; if two matches are
equally specific, the stricter mode wins.

For AZM 0.2.13, policy matching is intended to use the file that owns the
routine, finding, diagnostic, or suppression context. It is not limited to the
root assembly entry file. That means a monitor entry file can include legacy
modules and TECM8 can still audit those included files one at a time:

```asm
include "rtc.asm"
include "disassembler.asm"
```

```json
{
  "azm": {
    "registerContracts": "off",
    "registerContractsPolicy": {
      "audit": [
        "roms/tec1g/tecm8/monitor/rtc.asm",
        "roms/tec1g/tecm8/monitor/disassembler.asm"
      ],
      "strict": [
        "roms/tec1g/tecm8/monitor/new-code/**/*.asm"
      ],
      "off": [
        "roms/tec1g/tecm8/monitor/legacy/**/*.asm"
      ]
    },
    "emitRegisterReport": true
  }
}
```

This depends on AZM preserving include-file paths in spans. The register
contract implementation expects that shape: diagnostics filter by finding file,
routine boundary checks compare routine files, and suppression checks use the
file attached to the source line.

Debug80 shallow-merges `azm` options between config levels. Because
`registerContractsPolicy` is one `azm` property, a target-level policy replaces
the project-level policy object rather than merging individual `strict`,
`audit`, and `off` arrays. Keep the full policy in one place unless a target is
deliberately overriding it.

## TECM8 Policy

Use strict contracts for new TECM8-owned code:

```json
{
  "strict": [
    "src/**/*.asm",
    "proofs/**/*.asm",
    "roms/tec1g/tecm8/expansion/**/*.asm"
  ]
}
```

Use audit mode for the fixed monitor as it is cleaned up:

```json
{
  "audit": [
    "roms/tec1g/tecm8/monitor/monitor.asm",
    "roms/tec1g/tecm8/monitor/rtc.asm"
  ]
}
```

Move monitor include files from `off` to `audit`, and later from `audit` to
`strict`, only when they are retained code worth cleaning up. PATA/FAT32 and old
GLCD implementation code should not be prioritised if they are going to be
removed or moved behind expansion ROM service boundaries.

## Current Project Configuration

`debug80.json` now records the staged policy on the `main` target. The fallback
mode is `off`, with file-specific policy buckets used to keep the new code
strict without making the copied monitor source block ordinary ROM work.

Current target policy:

```json
{
  "registerContracts": "off",
  "registerContractsPolicy": {
    "strict": [
      "src/*.asm",
      "src/**/*.asm",
      "proofs/*.asm",
      "proofs/**/*.asm",
      "roms/tec1g/tecm8/expansion/*.asm",
      "roms/tec1g/tecm8/expansion/**/*.asm"
    ],
    "audit": [
      "roms/tec1g/tecm8/monitor/monitor.asm",
      "roms/tec1g/tecm8/monitor/rtc.asm",
      "roms/tec1g/tecm8/monitor/sound.asm",
      "roms/tec1g/tecm8/monitor/disassembler.asm"
    ],
    "off": [
      "roms/tec1g/mon3/**/*.asm",
      "roms/tec1g/tecm8/monitor/glcd_library.asm",
      "roms/tec1g/tecm8/monitor/pata_fat32.asm"
    ]
  },
  "registerContractsProfile": "mon3",
  "registerContractsInterfaces": [
    "roms/tec1g/tecm8/expansion/tecm8-rst-services.asmi"
  ],
  "emitRegisterReport": true
}
```

The policy is intentionally conservative: strict for TECM8-owned expansion
source and proofs, audit for retained monitor files, and off for old GLCD/PATA
implementation code that is expected to be removed or moved behind banked
services.

Direct-child and recursive globs are both listed deliberately. The policy must
match files such as `src/main.asm` and `roms/tec1g/tecm8/expansion/bank0.asm`,
not only files in nested subdirectories.

`npm run rom:contracts:check` remains the release gate for the expansion ROM.
It assembles every expansion bank directly with strict contracts and the
TecMate RST service interface. That keeps the banked ROM surface protected even
if a Debug80 launch path changes how target policy is applied.

Bank 5 relocates the retained MON3 `pata_fat32.asm` implementation beneath its
new sector-provider adapter. The adapter remains strict and calls the legacy
module through three conservative external contracts for `openFile`,
`readSector`, and `writeSector`. Register-contract findings owned by that legacy
file are reported separately and do not block the expansion gate; assembly and
syntax diagnostics are never quarantined. This confines the exception to the
unchanged imported implementation while keeping every new provider instruction
under strict checking.

## Practical Use Now

The existing monitor audit remains the baseline command:

```text
npm run mon3:contracts:audit
```

For the banked expansion ROM, direct AZM testing is now clean through the local
release gate:

```text
npm run rom:contracts:check
```

That makes the sensible rollout:

1. Keep expansion ROM code strict by default.
2. Keep exact `.asmi` contracts for registered `RST 10h` services.
3. Keep monitor cleanup file-scoped and incremental.
4. Move retained monitor includes from audit toward strict only when we are
   already editing them for TecMate.

## Debug80 Request

The ROM artifact path should either inherit target-level `azm` policy or support
artifact-level AZM options. The useful future shape is:

```json
{
  "tec1g": {
    "romArtifacts": [
      {
        "id": "tecm8-expansion",
        "azm": {
          "registerContracts": "strict",
          "registerContractsPolicy": {
            "strict": ["roms/tec1g/tecm8/expansion/**/*.asm"]
          },
          "registerContractsProfile": "mon3",
          "emitRegisterReport": true
        }
      },
      {
        "id": "tecm8-monitor",
        "azm": {
          "registerContracts": "off",
          "registerContractsPolicy": {
            "audit": ["roms/tec1g/tecm8/monitor/rtc.asm"],
            "off": ["roms/tec1g/tecm8/monitor/**/*.asm"]
          },
          "registerContractsProfile": "mon3",
          "emitRegisterReport": true
        }
      }
    ]
  }
}
```

The important point is that ROM artifacts need their own contract policy. The
fixed monitor, expansion banks, and ordinary application source are different
surfaces and should not all be forced into the same gate at the same time.
