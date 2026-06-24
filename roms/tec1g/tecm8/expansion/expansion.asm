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
