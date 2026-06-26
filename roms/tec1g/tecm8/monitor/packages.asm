; MON3 Additional Packages

; Include packages are to be placed in memory from 0D000H to 0FFECH

        ; MON3-lite compatibility stubs for relocated packages
        .include "monitor_lite_stubs.asm"

        ; Disassembler code
        .include "disassembler.asm"
        .include "sound.asm"
        .include "rtc.asm"
