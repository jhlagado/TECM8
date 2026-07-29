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

## Fixed-ROM Service Policy

The fixed monitor should be treated as the non-bank-switched BIOS and recovery
anchor. Anything that must be callable while the expansion window is changing
belongs here; anything larger that can live behind a stable entry point should
move to expansion ROM.

| Area | Fixed-ROM requirement | Direction |
| --- | --- | --- |
| Reset, soft boot, NMI/INT/RST stubs | Required recovery and compatibility entry points. | Keep fixed. |
| Monitor menu and memory monitor | Required TEC-1G turn-on personality and manual recovery path. | Keep fixed, but keep text compact. |
| Bank switching and far-call services | Required because `C000h-FFFFh` is the only stable code region while `8000h-BFFFh` changes banks. | Keep fixed. |
| Core RST 10h BIOS services | Required stable ABI for higher ROMs and RAM programs. | Keep fixed and document carefully. |
| Expansion discovery hook | Required bridge from the MON3 menu into a bank-0 supervisor. | Keep fixed as a tiny generic socket. |
| SD sector primitive | Candidate fixed service if it remains compact and reliable. | Keep only the low-level sector boundary. |
| PATA and FAT32 compatibility | Not a fixed-ROM requirement for the TecMate direction. | Replace with TEC-FS path; move compatibility elsewhere if retained. |
| TEC-FS volume/file logic | Useful operating-system service, but not necessarily fixed-ROM resident. | Prefer expansion ROM unless a tiny sector bridge is needed. |
| VDU/TMS9918 console | Core TecMate user interface service. | Keep in expansion ROM behind the banked ABI. |
| RTC base services | Useful if already resident and compact. | Keep low-level calls if needed; move RTC UI out. |
| GLCD support | Low priority unless it blocks fixed-ROM space or compatibility tests. | Leave alone until it interferes; then contain behind expansion services. |
| Disassembler | Useful MON3 personality and recovery tool. | Keep for now; reserve as a later space tradeoff. |

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
| 0 | Shell, launcher, registry | `2037` | `2037` | `87F5h` | `14347` |
| 1 | VDU/TMS9918 boundary | `568` | `568` | `8238h` | `15816` |
| 2 | TEC-FS boundary and block mapper | `4334` | `4334` | `90EEh` | `12050` |
| 3 | RTC boundary | `95` | `95` | `805Fh` | `16289` |
| 4 | Editor and optional GLCD boundary | `5004` | `5022` | `939Eh` | `11362` |
| 5 | TEC-FS monitor-sector bridge | `3430` | `3673` | `8E59h` | `12711` |
| 6 | Input snapshot boundary | `220` | `220` | `80DCh` | `16164` |
| 7 | Phase-one self-hosted assembler | `3724` | `3724` | `8E8Ch` | `12660` |
| 8 | Validated loader and runner | `2435` | `2435` | `8983h` | `13949` |

Expansion occupied bytes: `21847`

Expansion high-water span total: `22108`

Latest self-hosted build-and-run delta:

```text
bank 0 span: unchanged at 1320 bytes
bank 2 span: 1531 -> 2025 bytes
bank 4 span: 2180 -> 2231 bytes
bank 5 span: 279 -> 425 bytes
bank 7 span: 45 -> 2173 bytes
bank 8 span: 45 -> 256 bytes
expansion total span: 6283 -> 9313 bytes
fixed monitor span: unchanged at 16384 bytes
```

Latest real SD editor delta:

```text
bank 0 span: 1320 -> 1435 bytes
bank 2 span: 2025 -> 2574 bytes
bank 4 span: 2231 -> 2291 bytes
bank 5 span: 425 -> 3673 bytes
expansion total span: 9313 -> 13285 bytes
fixed monitor span: unchanged at 16384 bytes
```

Latest real SD directory delta:

```text
bank 0 span: 1435 -> 1745 bytes
bank 2 span: 2574 -> 2857 bytes
expansion total span: 13285 -> 13878 bytes
fixed monitor span: unchanged at 16384 bytes
```

Latest real SD source-creation delta:

```text
bank 2 span: 2857 -> 3640 bytes
bank 4 span: 2291 -> 2332 bytes
expansion total span: 13878 -> 14702 bytes
fixed monitor span: unchanged at 16384 bytes
```

Latest expressions and broader Z80 subset delta:

```text
bank 7 span: 2173 -> 3174 bytes
expansion total span: 14702 -> 15703 bytes
fixed monitor span: unchanged at 16384 bytes
```

Latest multi-file TEC-FS build delta:

```text
bank 2 span: 3640 -> 4064 bytes
bank 5 span: unchanged at 3673 bytes (occupied 3205 -> 3406)
bank 7 span: 3174 -> 3724 bytes
bank 8 span: 256 -> 327 bytes
expansion total span: 15703 -> 16748 bytes
fixed monitor span: unchanged at 16384 bytes
```

Latest SD workspace and recovery delta:

```text
bank 0 span: 2015 -> 2037 bytes
bank 2 span: 4064 -> 4334 bytes
bank 4 span: 2332 -> 5022 bytes
bank 5 span: unchanged at 3673 bytes (occupied 3406 -> 3430)
expansion total span: 19126 -> 22108 bytes
fixed monitor span: unchanged at 16384 bytes
```

The important practical point is that the expansion ROM is still almost empty.
The fixed monitor remains full, but the service ABI is now giving MON3 and later
TecMate code a controlled path into expansion ROMs without needing to make the
fixed monitor carry every subsystem.

## Current Boundary Locations

The most important expansion locations are below. Only the header/install
contract and monitor RAM vectors are public discovery ABI; dispatcher, shell,
registry, and marker labels are current private bank-0 layout.

| Entry | Address | Notes |
| --- | ---: | --- |
| Bank 0 header | `8000h` | `EXPR` discovery header data, not a routine entry. |
| Bank 0 install | `800Bh` | Installs menu/service vectors into MON3 RAM. |
| Bank 0 menu provider | `802Ah` | Demo/front-door entry installed by bank 0. |
| Bank 0 service dispatcher | `8080h` | Private table-driven label installed into the service vector. |
| Bank 0 service registry | `87C2h` | Private service ID to bank/address/target-`A` table. |
| Bank 0 shell entry | `80BEh` | Private descriptor and VDU home-screen path for `SHL_ENTRY`. |
| Bank 0 shell command boundary | `8111h` | Private one-command dispatcher reached through `SHL_RUN_COMMAND`. |
| Bank 0 shell status renderer | `8495h` | Private VDU status-line publisher reached through `SHL_RENDER_STATUS`. |
| Bank 0 shell result renderer | `84E0h` | Private VDU result publisher reached through `SHL_RENDER_RESULT`. |
| Bank 0 info marker | `87BDh` | Private marker, not a fixed ABI location. |
| Bank 1 VDU/TMS dispatcher | `8000h` | Dispatches bank-local VDU/TMS service IDs in `A`. |
| Bank 2 TEC-FS dispatcher | `8000h` | Dispatches TEC-FS service IDs in `A`. |
| Bank 2 TEC-FS map block | private label | Maps active volume/block to 512-byte sector. |
| Bank 3 RTC entry | `8000h` | RTC boundary descriptor. |
| Bank 4 editor/GLCD entry | `8000h` | Dispatches interactive editor open/run/step/blink services and the optional GLCD boundary. |
| Bank 6 input snapshot dispatcher | `8000h` | Dispatches bank-local input service IDs in `A`. |
| Bank 7 assembler dispatcher | `8000h` | Dispatches bank-local assembler service IDs in `A`. |
| Bank 8 run dispatcher | `8000h` | Dispatches bank-local run service IDs in `A`. |

## Consequences

- The immediate pressure is still in fixed monitor ROM, not the expansion ROM.
- Banked services are cheap at this stage; the total occupied expansion code is
  compact after adding the TEC-FS-backed persistent interactive editor path.
- Bank 0 layout now needs active care because it contains both the registry and
  shell launcher boundary. Private labels may move; callers should enter through
  discovery-installed vectors and service IDs, not internal marker addresses.
- The next meaningful fixed-ROM space work should focus on replacing the old
  PATA/FAT32 storage path with the TEC-FS direction and moving user-interface
  workflows out of the monitor.
- GLCD remains a low-priority containment issue. Do not spend near-term effort
  moving it unless it blocks fixed-ROM space, service layout, or compatibility
  testing.
