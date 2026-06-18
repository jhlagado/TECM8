; TECM8 editor key normalization and command lookup.

; EditorModifiedCommandFromKey -
; Prefer Control-aware editor commands before printable insertion. This catches
; Ctrl-letter events when the host path reports a printable letter plus modifier
; flags instead of an ASCII control byte.
; Input: EditorPendingChar, EditorPendingModifier
; Output: A = TECM8_EDITOR_KEY_* command or 0
;! out A,carry
;! clobbers E,HL,zero,sign,parity,halfCarry
@EditorModifiedCommandFromKey:
        LD      A,(EditorPendingModifier)
        AND     TECM8_EDITOR_KEY_MOD_CTRL
        JR      Z,EditorModifiedCommandNone
        LD      A,(EditorPendingChar)
        CP      "A"
        JR      C,EditorModifiedCommandNormalized
        CP      "Z" + 1
        JR      NC,EditorModifiedCommandNormalized
        OR      0x20
EditorModifiedCommandNormalized:
        LD      HL,EditorModifiedCommandTable
        CALL    EditorModifiedCommandLookup
        OR      A
        RET     NZ
        LD      A,(EditorPendingChar)
        CP      TECM8_EDITOR_KEY_CTRL_C
        JR      Z,EditorModifiedCommandControlByteCopy

EditorModifiedCommandNone:
        XOR     A
        RET

EditorModifiedCommandLookup:
        LD      E,A
EditorModifiedCommandLookupLoop:
        LD      A,(HL)
        OR      A
        JR      Z,EditorModifiedCommandNone
        CP      E
        INC     HL
        JR      Z,EditorModifiedCommandLookupFound
        INC     HL
        JR      EditorModifiedCommandLookupLoop

EditorModifiedCommandLookupFound:
        LD      A,(HL)
        OR      A
        RET

; Byte 0x03 is a copy command only when it came from the C key with Control.
; If the physical matrix key was Up Arrow, movement handling owns the event.
EditorModifiedCommandControlByteCopy:
        LD      A,(BiosInputRawPrimary)
        CP      TECM8_EDITOR_KEY_ARROW_UP
        JR      Z,EditorModifiedCommandNone
        LD      A,"C"
        OR      A
        RET

EditorModifiedCommandTable:
        .db     "s",TECM8_EDITOR_KEY_SAVE
        .db     "q",TECM8_EDITOR_KEY_QUIT
        .db     "z",TECM8_EDITOR_KEY_RESTORE
        .db     "c","C"
        .db     "x","X"
        .db     "v","V"
        .db     "y","Y"
        .db     TECM8_EDITOR_KEY_CTRL_X,"X"
        .db     TECM8_EDITOR_KEY_CTRL_V,"V"
        .db     TECM8_EDITOR_KEY_CTRL_Y,"Y"
        .db     0

; EditorShouldIgnoreModifiedPrintable -
; Return A=1 when a Ctrl-modified printable key did not match a known command.
; This prevents a failed host modifier chord from inserting text.
;! out A,carry,zero
;! clobbers sign,parity,halfCarry
@EditorShouldIgnoreModifiedPrintable:
        LD      A,(EditorPendingModifier)
        AND     TECM8_EDITOR_KEY_MOD_CTRL
        JR      Z,EditorShouldIgnoreModifiedPrintableNo
        LD      A,(EditorPendingChar)
        CP      TECM8_EDITOR_KEY_PRINTABLE_MIN
        JR      C,EditorShouldIgnoreModifiedPrintableNo
        CP      TECM8_EDITOR_KEY_PRINTABLE_MAX + 1
        JR      NC,EditorShouldIgnoreModifiedPrintableNo
        LD      A,1
        OR      A
        RET

EditorShouldIgnoreModifiedPrintableNo:
        XOR     A
        RET
