; TECM8 monitor ROM scaffold.
;
; This stub is the active fixed monitor ROM while the TECM8 monitor replacement
; grows. It deliberately parks execution in Tecm8MonitorHold.

        .org    0xC000

TECM8_MONITOR_VERSION          .equ    0x01

@Tecm8MonitorEntry:
        JP      Tecm8MonitorHold

@Tecm8MonitorInfo:
        .db     "T","M","8",TECM8_MONITOR_VERSION

Tecm8MonitorHold:
        JP      Tecm8MonitorHold
