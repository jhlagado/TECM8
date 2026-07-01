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

## Current Debug80 Limitation

The policy is wired through Debug80's ordinary AZM launch path, but TEC-1G ROM
artifact builds currently still force:

```text
registerContracts: off
emitRegisterReport: false
```

That means adding the policy to `debug80.json` will help normal project source
builds, but it will not yet check the monitor or expansion ROM artifacts during
Debug80's automatic ROM build.

Until Debug80 exposes contract policy to ROM artifacts, TECM8 should use local
audit/build scripts for ROM contract checks.

## Practical Use Now

The existing monitor audit remains the baseline command:

```text
npm run mon3:contracts:audit
```

For the banked expansion ROM, direct AZM testing with Debug80's AZM 0.2.13 shows
that strict policy already works on the source files. The first strict pass
currently reports a small number of real annotation/contract issues in banks 0,
1, and 2, and no diagnostics in banks 3 through 8.

That makes the sensible rollout:

1. Keep expansion ROM code strict by default.
2. Fix or annotate the current bank 0-2 diagnostics.
3. Keep monitor cleanup file-scoped and incremental.
4. Ask Debug80 to stop forcing register contracts off for TEC-1G ROM artifact
   builds, or to add artifact-level AZM policy.

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
