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
