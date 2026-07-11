; TECM8 GLCD tile row convenience helpers.
;
; These wrappers are useful for diagnostics and proofs, but the main editor
; should prefer narrower cell/span rendering paths.

; GlcdTileClearTextRow -
; Clear all 20 text cells on one display row.
; Input: B = row (0-9)
.routine in B out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
GlcdTileClearTextRow:
        LD      A,B
        CP      TECM8_GLCD_TILE_ROWS
        JP      NC,GlcdTileRangeError
        LD      (GlcdTileTextRow),A
        XOR     A
        LD      (GlcdTileTextColumn),A

GlcdTileClearTextRowLoop:
        LD      A,(GlcdTileTextColumn)
        CP      TECM8_GLCD_TILE_COLUMNS
        JR      NC,GlcdTileClearTextRowDone
        LD      C,A
        LD      A,(GlcdTileTextRow)
        LD      B,A
        CALL    GlcdTileClearCell
        RET     C
        LD      A,(GlcdTileTextColumn)
        INC     A
        LD      (GlcdTileTextColumn),A
        JR      GlcdTileClearTextRowLoop

GlcdTileClearTextRowDone:
        XOR     A
        RET
