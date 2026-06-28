# TecMate ROM Space Map

This records the current ROM-space position after the first banked service ABI
increments. The numbers come from `npm run rom:check` and the generated D8
segments for the TecMate monitor and nine-bank expansion ROM.

## Fixed Monitor ROM

The monitor still builds as a full fixed 16K image from `C000h` to `FFFFh`.
The current monitor source span is `16384` bytes, so there is no measurable
free high-water space in the fixed monitor image yet.

```text
monitor window:        C000h-FFFFh
monitor image bytes:   16384
monitor source span:   16384
monitor free by span:  0
```

This does not mean every byte is strategically valuable. It means the current
assembled image still reaches the end of the fixed ROM window. The active
strategy remains to keep fixed-ROM changes small, put bank-switching and stable
BIOS entry points there, and move larger subsystems into expansion banks.

## Expansion ROM

The expansion image is a 144K artifact made from nine physical 16K banks. Each
bank is assembled for the visible `8000h-BFFFh` expansion window and then packed
into the backing image.

Terms:

- Occupied bytes: sum of emitted D8 segments in the bank.
- Span bytes: bytes from `8000h` to the high-water end address in the bank.
- High-water end: the D8 segment end address, which is end-exclusive. For
  example, an end of `8165h` means the highest emitted byte is `8164h`.
- Free after high-water: `16384 - span bytes`.

| Bank | Current role | Occupied bytes | Span bytes | High-water end exclusive | Free after high-water |
| ---: | --- | ---: | ---: | ---: | ---: |
| 0 | Shell, launcher, registry | `206` | `357` | `8165h` | `16027` |
| 1 | VDU/TMS9918 boundary | `136` | `261` | `8105h` | `16123` |
| 2 | TEC-FS boundary and block mapper | `298` | `581` | `8245h` | `15803` |
| 3 | RTC boundary | `65` | `261` | `8105h` | `16123` |
| 4 | GLCD boundary | `53` | `261` | `8105h` | `16123` |
| 5 | Reserved stub | `6` | `6` | `8006h` | `16378` |
| 6 | Reserved stub | `6` | `6` | `8006h` | `16378` |
| 7 | Reserved stub | `6` | `6` | `8006h` | `16378` |
| 8 | Reserved stub | `6` | `6` | `8006h` | `16378` |

Expansion occupied bytes: `782`

Expansion high-water span total: `1745`

The important practical point is that the expansion ROM is still almost empty.
The fixed monitor remains full, but the service ABI is now giving MON3 and later
TecMate code a controlled path into expansion ROMs without needing to make the
fixed monitor carry every subsystem.

## Current Boundary Locations

The most important fixed expansion entry points are:

| Entry | Address | Notes |
| --- | ---: | --- |
| Bank 0 entry | `8000h` | Demo/front-door entry. |
| Bank 0 service registry | `80A0h` | Dispatches `callService` requests. |
| Bank 0 shell entry | `8120h` | Descriptor stub for `TECM8_SERVICE_SHELL_ENTRY`. |
| Bank 0 info marker | `8160h` | Moved after shell stub to avoid overlap. |
| Bank 1 VDU init | `8010h` | First TMS9918-facing service. |
| Bank 2 TEC-FS mount | `8010h` | Publishes TEC-FS geometry. |
| Bank 2 TEC-FS map block | `8070h` | Maps active volume/block to 512-byte sector. |
| Bank 3 RTC entry | `8000h` | RTC boundary descriptor. |
| Bank 4 GLCD entry | `8000h` | GLCD boundary descriptor. |

## Consequences

- The immediate pressure is still in fixed monitor ROM, not the expansion ROM.
- Banked services are cheap at this stage; the total occupied expansion code is
  under 1K.
- Bank 0 layout now needs active care because it contains both the registry and
  shell launcher boundary. The `8160h` info marker leaves room for registry
  growth, but it should move again if the dispatcher gets larger.
- The next meaningful space work should measure real candidate moves from fixed
  monitor ROM: PATA/FAT32, GLCD terminal/library code, and RTC UI.
