; TECM8 editor input entry points.
;
; This module owns key-stream setup, one-shot modified-key ingestion, and the
; live matrix-key polling loop. Command execution remains in
; src/editor-interaction.asm.

; EditorRunKeys -
; Consume a NUL-terminated translated-key stream used by proof fixtures.
; Movement and paging are physical arrow-key actions only. TAB enters insert
; mode, printable ASCII inserts, backspace deletes before the cursor, delete
; removes the character at the cursor, newline splits the current record, and
; unknown keys are ignored.
; Input:
;   HL = NUL-terminated key stream
.routine in HL out A,carry clobbers zero,sign,parity,halfCarry,BC,DE,HL
EditorRunKeys:
        LD      (EditorKeyStreamPtr),HL
        XOR     A
        LD      (EditorKeyStreamModifier),A
        LD      (EditorInsertMode),A
        LD      (EditorQuitRequested),A
        JP      EditorKeyLoop

; EditorRunModifiedKey -
; Consume one translated key event with modifier flags.
; Input:
;   A = translated key
;   B = modifier flags
.routine in A,B out A,carry clobbers zero,sign,parity,halfCarry,BC,DE,HL
EditorRunModifiedKey:
        LD      C,A
        LD      A,(BiosInputRawSecondary)
        CP      0xFF
        JR      NZ,EditorRunModifiedKeyRawPrimaryReady
        LD      A,B
        AND     TECM8_EDITOR_KEY_MOD_CTRL
        JR      Z,EditorRunModifiedKeyMaybeSyntheticArrow
        LD      A,C
        CP      TECM8_EDITOR_KEY_CTRL_C
        JR      Z,EditorRunModifiedKeyClearRawPrimary

EditorRunModifiedKeyMaybeSyntheticArrow:
        LD      A,C
        CP      TECM8_EDITOR_KEY_ARROW_UP
        JR      C,EditorRunModifiedKeyClearRawPrimary
        CP      TECM8_EDITOR_KEY_ARROW_RIGHT + 1
        JR      NC,EditorRunModifiedKeyClearRawPrimary
        LD      (BiosInputRawPrimary),A
        JR      EditorRunModifiedKeyRawPrimaryReady

EditorRunModifiedKeyClearRawPrimary:
        LD      A,0xFF
        LD      (BiosInputRawPrimary),A

EditorRunModifiedKeyRawPrimaryReady:
        LD      A,C
        LD      (EditorLiveKeyBuffer),A
        LD      A,B
        LD      (EditorKeyStreamModifier),A
        LD      HL,EditorLiveKeyBuffer
        LD      (EditorKeyStreamPtr),HL
        JP      EditorKeyLoop

; EditorRunLive -
; Poll TECM8 key events from the MON3-backed matrix scanner until the editor
; requests quit. A/B carry the editor-facing translated key and modifier flags;
; raw D/E remains available at the BIOS layer for diagnostics.
.routine out A,carry clobbers zero,sign,parity,halfCarry,BC,DE,HL
EditorRunLive:
        XOR     A
        LD      (EditorQuitRequested),A
        LD      (EditorInsertMode),A
        CALL    EditorRenderCursor
        RET     C
        CALL    EditorCursorBlinkReset
        RET     C

EditorLiveLoop:
        LD      A,(EditorQuitRequested)
        OR      A
        JP      NZ,EditorLiveDone
        CALL    BiosInputPollKey
        JR      NC,EditorLiveIdle
        CALL    EditorRunModifiedKey
        RET     C
        JP      EditorLiveLoop

EditorLiveIdle:
        CALL    Tecm8DisplayStep
        RET     C
        OR      A
        JR      NZ,EditorLiveIdleDelay
        CALL    EditorCursorBlinkStep
        RET     C
EditorLiveIdleDelay:
        LD      B,TECM8_EDITOR_LIVE_IDLE_SPINS

EditorLiveIdleLoop:
        DJNZ    EditorLiveIdleLoop
        JP      EditorLiveLoop

EditorLiveDone:
        CALL    EditorRenderCursor
        RET

EditorKeyStreamPtr:
        .dw     0

EditorLiveKeyBuffer:
        .db     0,0

EditorKeyStreamModifier:
        .db     0

EditorPendingModifier:
        .db     0

EditorPendingChar:
        .db     0

EditorInsertMode:
        .db     0

EditorQuitRequested:
        .db     0
