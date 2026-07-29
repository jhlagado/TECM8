; Real SD-backed TEC-FS path proof.
;
; Runs from RAM with the project monitor and expansion ROM. The proof resolves
; /src/main.asm through bank 2, loads it through bank 5's MON3 file driver,
; changes the first source character, saves data then metadata, and reopens it.

        .org    0x4000

        .include "../../roms/tec1g/tecm8/expansion/bank_ops.asmi"

PROOF_PASS          .equ    0x42
PROOF_FAIL_FIND     .equ    0xE1
PROOF_FAIL_LOAD     .equ    0xE2
PROOF_FAIL_CONTENT  .equ    0xE3
PROOF_FAIL_SAVE     .equ    0xE4
PROOF_FAIL_COMMIT   .equ    0xE5
PROOF_FAIL_REOPEN   .equ    0xE6
PROOF_RESULT        .equ    0x3A10
PROOF_PHASE         .equ    0x3A11

.routine out carry,zero clobbers sign,parity,halfCarry,A,B,C,D,E,H,L
Start:
        xor a
        ld (PROOF_RESULT),a
        ld a,TFS_BRIDGE_BANK
        ld (TFS_PARAM_DRIVER_BANK),a
        ld hl,TFS_MON3_FILE_DRIVER
        ld (TFS_PARAM_DRIVER_ADDR_LO),hl
        ld hl,ProofPath
        ld (TFS_PARAM_PATH_LO),hl

        ld a,1
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_FIND_PATH
        farCall TFS_BANK,TFS_ENTRY
        jp c,FailFind

        ld hl,EDT_BUFFER_BASE
        ld (TFS_PARAM_LOAD_DEST_LO),hl
        ld hl,EDT_BUFFER_BYTES
        ld (TFS_PARAM_LOAD_BYTES_LO),hl
        ld a,2
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_LOAD_SOURCE
        farCall TFS_BANK,TFS_ENTRY
        jp c,FailLoad

        ld a,(EDT_BUFFER_BASE)
        cp 5
        jp nz,FailContent
        ld a,(EDT_BUFFER_BASE+1)
        cp "O"
        jp nz,FailContent
        ld a,"X"
        ld (EDT_BUFFER_BASE+1),a

        xor a
        ld (TFS_PARAM_SOURCE_PAGE),a
        ld hl,EDT_BUFFER_BASE
        ld (TFS_PARAM_LOAD_DEST_LO),hl
        ld a,3
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_SAVE_SOURCE_PAGE
        farCall TFS_BANK,TFS_ENTRY
        jp c,FailSave
        ld a,4
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_COMMIT_SOURCE_META
        farCall TFS_BANK,TFS_ENTRY
        jp c,FailCommit

        xor a
        ld (EDT_BUFFER_BASE+1),a
        ld hl,ProofPath
        ld (TFS_PARAM_PATH_LO),hl
        ld a,5
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_FIND_PATH
        farCall TFS_BANK,TFS_ENTRY
        jp c,FailReopen
        ld hl,EDT_BUFFER_BASE
        ld (TFS_PARAM_LOAD_DEST_LO),hl
        ld hl,EDT_BUFFER_BYTES
        ld (TFS_PARAM_LOAD_BYTES_LO),hl
        ld a,6
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_LOAD_SOURCE
        farCall TFS_BANK,TFS_ENTRY
        jp c,FailReopen
        ld a,(EDT_BUFFER_BASE+1)
        cp "X"
        jp nz,FailReopen

        ; Exercise the actual TMS9918 editor over the same SD-backed path.
        ld a,VDU_SVC_INIT
        farCall VDU_BANK,VDU_ENTRY
        jp c,FailEditor
        ld hl,ProofEditorEvents
        ld de,INP_QUEUE_BASE
        ld bc,6
        ldir
        xor a
        ld (INP_QUEUE_HEAD),a
        ld a,3
        ld (INP_QUEUE_COUNT),a
        ld hl,ProofTarget
        ld (EDT_PARAM_TARGET_LO),hl
        ld a,EDT_SVC_RUN
        farCall EDT_BANK,EDT_ENTRY
        jp c,FailEditor
        ld a,(EDT_PARAM_RESULT)
        cp SHL_RESULT_OK
        jp nz,FailEditor
        ld a,(EDT_STATE_SAVE_COUNT)
        cp 1
        jp nz,FailEditor

        xor a
        ld (EDT_BUFFER_BASE+1),a
        ld hl,ProofQuitEvent
        ld de,INP_QUEUE_BASE
        ld bc,2
        ldir
        xor a
        ld (INP_QUEUE_HEAD),a
        inc a
        ld (INP_QUEUE_COUNT),a
        ld hl,ProofTarget
        ld (EDT_PARAM_TARGET_LO),hl
        ld a,EDT_SVC_RUN
        farCall EDT_BANK,EDT_ENTRY
        jp c,FailEditor
        ld a,(EDT_BUFFER_BASE+1)
        cp "E"
        jp nz,FailEditor
        ld a,(EDT_BUFFER_BASE+2)
        cp "X"
        jp nz,FailEditor

        ld a,PROOF_PASS
        ld (PROOF_RESULT),a
        ld a,7
        ld (PROOF_PHASE),a
        halt

FailFind:
        ld a,PROOF_FAIL_FIND
        jr Fail
FailLoad:
        ld a,PROOF_FAIL_LOAD
        jr Fail
FailContent:
        ld a,PROOF_FAIL_CONTENT
        jr Fail
FailSave:
        ld a,PROOF_FAIL_SAVE
        jr Fail
FailCommit:
        ld a,PROOF_FAIL_COMMIT
        jr Fail
FailReopen:
        ld a,PROOF_FAIL_REOPEN
        jr Fail
FailEditor:
        ld a,0xE7
Fail:
        ld (PROOF_RESULT),a
        halt

ProofPath:
        .db     "/src/main.asm",0

ProofTarget:
        .db     SHL_ACTION_EDIT,SHL_TARGET_KIND_SOURCE_PATH
        .dw     ProofPath
        .db     0

ProofEditorEvents:
        .db     "E",0
        .db     EDT_KEY_SAVE,EDT_KEY_MOD_CTRL
ProofQuitEvent:
        .db     EDT_KEY_QUIT,EDT_KEY_MOD_CTRL
