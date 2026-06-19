; TECM8 display service facade.
;
; Editor modules call through these service-named wrappers instead of directly
; binding to the current GLCD tile/model implementation. The wrappers tail-call
; their targets so the runtime cost is one JP per service entry, while AZM can
; still prove register contracts at call sites.

; Tecm8DisplayStep -
; Transfer one pending display step, if any.
;! out A,carry,zero
;! clobbers sign,parity,halfCarry,BC,DE,HL
@Tecm8DisplayStep:
        JP      GlcdTileStep

; Tecm8DisplayMarkRowDirty -
; Queue one full text row for cooperative transfer.
; Input: A = row (0-9)
;! in A
;! out A,carry,zero
;! clobbers sign,parity,halfCarry,BC,DE,HL
@Tecm8DisplayMarkRowDirty:
        JP      GlcdTileMarkRowDirty

; Tecm8DisplayMarkCellDirty -
; Queue one text cell for cooperative transfer.
; Input: B = row (0-9), C = column (0-19)
;! in BC
;! out A,carry,zero
;! clobbers sign,parity,halfCarry,BC,DE,HL
@Tecm8DisplayMarkCellDirty:
        JP      GlcdTileMarkCellDirty

; Tecm8DisplayMarkGutterDirty -
; Queue the gutter byte pair for one text row.
; Input: A = row (0-9)
;! in A
;! out carry
;! clobbers zero,sign,parity,halfCarry,A,BC,DE,HL
@Tecm8DisplayMarkGutterDirty:
        JP      GlcdTileMarkGutterDirty

; Tecm8DisplayFlushFull -
; Push the whole display bitmap through the active backend.
;! out carry
;! clobbers zero,sign,parity,halfCarry,A,BC,DE,HL
@Tecm8DisplayFlushFull:
        JP      GlcdTileFlushFull

; Tecm8DisplayFlushRow -
; Push one queued text row synchronously.
; Input: A = row (0-9)
;! in A
;! out A,carry,zero
;! clobbers sign,parity,halfCarry,BC,DE,HL
@Tecm8DisplayFlushRow:
        JP      GlcdTileFlushRow

; Tecm8DisplayRenderLine -
; Render one row with gutter marker and text.
; Input: A = display row, C = marker flags, HL = NUL-terminated text
;! in A,C,HL
;! out carry
;! clobbers zero,sign,parity,halfCarry,A,BC,DE,HL
@Tecm8DisplayRenderLine:
        JP      DisplayRenderLine

; Tecm8DisplayRenderCursorCell -
; Overlay the insertion cursor.
; Input: A = edit row (0-9), C = text column (0-19)
;! in A,C
;! out A,carry,zero
;! clobbers sign,parity,halfCarry,BC,DE,HL
@Tecm8DisplayRenderCursorCell:
        JP      DisplayRenderCursorCell

; Tecm8DisplayEraseCursorCell -
; Remove the insertion cursor overlay.
; Input: A = edit row (0-9), C = text column (0-19)
;! in A,C
;! out A,carry,zero
;! clobbers sign,parity,halfCarry,BC,DE,HL
@Tecm8DisplayEraseCursorCell:
        JP      DisplayEraseCursorCell
