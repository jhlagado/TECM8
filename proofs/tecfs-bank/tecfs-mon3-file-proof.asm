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
PROOF_FAIL_LIST     .equ    0xE8
PROOF_FAIL_CREATE   .equ    0xE9
PROOF_FAIL_BUILD    .equ    0xEA
PROOF_FAIL_RUN      .equ    0xEB
PROOF_RESULT        .equ    0x3A10
PROOF_PHASE         .equ    0x3A11
PROOF_LIST_BUFFER   .equ    0x5800
PROGRAM_MARKER      .equ    0x4FF0

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
        call ProofListDirectory
        jp c,FailList

        ld hl,ProofPath
        ld (TFS_PARAM_PATH_LO),hl
        ld a,2
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_FIND_PATH
        farCall TFS_BANK,TFS_ENTRY
        jp c,FailFind

        ld hl,EDT_BUFFER_BASE
        ld (TFS_PARAM_LOAD_DEST_LO),hl
        ld hl,EDT_BUFFER_BYTES
        ld (TFS_PARAM_LOAD_BYTES_LO),hl
        ld a,3
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
        ld a,4
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_SAVE_SOURCE_PAGE
        farCall TFS_BANK,TFS_ENTRY
        jp c,FailSave
        ld a,5
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_COMMIT_SOURCE_META
        farCall TFS_BANK,TFS_ENTRY
        jp c,FailCommit

        xor a
        ld (EDT_BUFFER_BASE+1),a
        ld hl,ProofPath
        ld (TFS_PARAM_PATH_LO),hl
        ld a,6
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_FIND_PATH
        farCall TFS_BANK,TFS_ENTRY
        jp c,FailReopen
        ld hl,EDT_BUFFER_BASE
        ld (TFS_PARAM_LOAD_DEST_LO),hl
        ld hl,EDT_BUFFER_BYTES
        ld (TFS_PARAM_LOAD_BYTES_LO),hl
        ld a,7
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

        call ProofCreateSource
        jp c,FailCreate

        call ProofShellDirectory
        jp c,FailList

        call ProofBuildAndRun
        jp c,FailBuildOrRun

        ld a,PROOF_PASS
        ld (PROOF_RESULT),a
        ld a,12
        ld (PROOF_PHASE),a
        halt

ProofListDirectory:
        ld hl,ProofDirPath
        ld (TFS_PARAM_PATH_LO),hl
        ld hl,PROOF_LIST_BUFFER
        ld (TFS_PARAM_LIST_DEST_LO),hl
        ld hl,0x0100
        ld (TFS_PARAM_LIST_CAP_LO),hl
        ld a,TFS_SVC_LIST_PATH
        farCall TFS_BANK,TFS_ENTRY
        ret c
        ld a,(TFS_PARAM_LIST_COUNT)
        cp 2
        scf
        ret nz
        ld hl,PROOF_LIST_BUFFER
        ld de,ProofExpectedList
ProofCheckList:
        ld a,(de)
        cp (hl)
        scf
        ret nz
        inc de
        inc hl
        or a
        jr nz,ProofCheckList
        ld hl,(TFS_PARAM_LIST_USED_LO)
        ld de,19
        or a
        sbc hl,de
        scf
        ret nz

        ; A short destination must report truncation without copying a
        ; partial first name or touching the next byte.
        ld a,0xA5
        ld (PROOF_LIST_BUFFER+1),a
        ld hl,ProofDirPath
        ld (TFS_PARAM_PATH_LO),hl
        ld hl,PROOF_LIST_BUFFER
        ld (TFS_PARAM_LIST_DEST_LO),hl
        ld hl,5
        ld (TFS_PARAM_LIST_CAP_LO),hl
        ld a,TFS_SVC_LIST_PATH
        farCall TFS_BANK,TFS_ENTRY
        ret c
        ld a,(TFS_PARAM_LIST_COUNT)
        or a
        scf
        ret nz
        ld a,(TFS_PARAM_LIST_FLAGS)
        cp TFS_LIST_FLAG_TRUNCATED
        scf
        ret nz
        ld hl,(TFS_PARAM_LIST_USED_LO)
        ld de,1
        or a
        sbc hl,de
        scf
        ret nz
        ld a,(PROOF_LIST_BUFFER)
        or a
        scf
        ret nz
        ld a,(PROOF_LIST_BUFFER+1)
        cp 0xA5
        scf
        ret nz
        or a
        ret

ProofShellDirectory:
        ld a,SHL_BANK
        farCall SHL_BANK,EXP_BANK0_INSTALL
        ld hl,ProofDirCommand
        ld de,SHL_COMMAND_BUFFER
        ld bc,ProofDirCommandEnd-ProofDirCommand
        ldir
        callService SHL_RUN_COMMAND
        ret c
        ld a,(SHL_PARAM_COMMAND_RESULT_LO)
        cp SHL_RESULT_OK
        scf
        ret nz
        ld a,(SHL_PARAM_COMMAND_RESULT_HI)
        cp 3
        scf
        ret nz
        ld a,VDU_SVC_INIT
        farCall VDU_BANK,VDU_ENTRY
        ret c
        callService SHL_RENDER_RESULT
        ret

ProofCreateSource:
        ld hl,ProofCreateEvents
        ld de,INP_QUEUE_BASE
        ld bc,6
        ldir
        xor a
        ld (INP_QUEUE_HEAD),a
        ld a,3
        ld (INP_QUEUE_COUNT),a
        ld hl,ProofNewTarget
        ld (EDT_PARAM_TARGET_LO),hl
        ld a,8
        ld (PROOF_PHASE),a
        ld a,EDT_SVC_RUN
        farCall EDT_BANK,EDT_ENTRY
        ret c
        ld a,(EDT_PARAM_RESULT)
        cp SHL_RESULT_OK
        scf
        ret nz
        xor a
        ld (EDT_BUFFER_BASE),a
        ld (EDT_BUFFER_BASE+1),a
        ld hl,ProofNewTarget
        ld (EDT_PARAM_TARGET_LO),hl
        ld a,EDT_SVC_OPEN
        farCall EDT_BANK,EDT_ENTRY
        ret c
        ld a,(EDT_PARAM_RESULT)
        cp SHL_RESULT_OK
        scf
        ret nz
        ld a,(EDT_BUFFER_BASE)
        cp 1
        scf
        ret nz
        ld a,(EDT_BUFFER_BASE+1)
        cp "N"
        scf
        ret nz
        ld hl,ProofNewPath
        ld (TFS_PARAM_PATH_LO),hl
        ld a,TFS_SVC_CREATE_SOURCE
        farCall TFS_BANK,TFS_ENTRY
        jr nc,ProofCreateUnexpectedSuccess
        ld a,(TFS_PARAM_LAST_ERROR)
        cp TFS_ERR_EXISTS
        scf
        ret nz
        ld hl,ProofBadCreatePath
        ld (TFS_PARAM_PATH_LO),hl
        ld a,TFS_SVC_CREATE_SOURCE
        farCall TFS_BANK,TFS_ENTRY
        jr nc,ProofCreateUnexpectedSuccess
        ld a,(TFS_PARAM_LAST_ERROR)
        cp TFS_ERR_BAD_PATH
        scf
        ret nz
        or a
        ret
ProofCreateUnexpectedSuccess:
        scf
        ret

ProofBuildAndRun:
        ld hl,ProofBuildPath
        ld (TFS_PARAM_PATH_LO),hl
        ld a,9
        ld (PROOF_PHASE),a
        ld a,TFS_SVC_FIND_PATH
        farCall TFS_BANK,TFS_ENTRY
        ret c
        ld hl,EDT_BUFFER_BASE
        ld (TFS_PARAM_LOAD_DEST_LO),hl
        ld hl,EDT_BUFFER_BYTES
        ld (TFS_PARAM_LOAD_BYTES_LO),hl
        ld a,TFS_SVC_LOAD_SOURCE
        farCall TFS_BANK,TFS_ENTRY
        ret c
        ld a,(TFS_PARAM_LOAD_LINES_HI)
        or a
        scf
        ret nz
        ld a,(TFS_PARAM_LOAD_LINES_LO)
        cp 6
        scf
        ret nz
        ld (EDT_STATE_TOTAL_LINES),a

        ld hl,ProofBuildTarget
        ld (ASM_PARAM_TARGET_LO),hl
        ld a,10
        ld (PROOF_PHASE),a
        ld a,ASM_SVC_ASSEMBLE
        farCall ASM_BANK,ASM_ENTRY
        jr c,ProofBuildFailed
        ld a,(ASM_PARAM_RESULT_LO)
        cp SHL_RESULT_OK
        jr nz,ProofBuildFailed
        ld hl,(ASM_PARAM_OUTPUT_SIZE_LO)
        ld de,10
        or a
        sbc hl,de
        jr nz,ProofBuildFailed
        ld a,(TFS_PARAM_ARTIFACT_DATA_WRITES)
        cp 2
        jr nz,ProofBuildFailed
        ld a,(TFS_PARAM_ARTIFACT_META_WRITES)
        cp 2
        jr nz,ProofBuildFailed

        xor a
        ld (PROGRAM_MARKER),a
        ld hl,ProofRunTarget
        ld (RUN_PARAM_TARGET_LO),hl
        ld a,11
        ld (PROOF_PHASE),a
        ld a,RUN_SVC_RUN
        farCall RUN_BANK,RUN_ENTRY
        jr c,ProofRunFailed
        ld a,(RUN_PARAM_RESULT_LO)
        cp SHL_RESULT_OK
        jr nz,ProofRunFailed
        ld a,(PROGRAM_MARKER)
        cp 0x5A
        jr nz,ProofRunFailed
        ld a,(RUN_PARAM_RETURN_COUNT)
        cp 1
        jr nz,ProofRunFailed
        or a
        ret
ProofBuildFailed:
        ld a,PROOF_FAIL_BUILD
        scf
        ret
ProofRunFailed:
        ld a,PROOF_FAIL_RUN
        scf
        ret

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
FailList:
        ld a,PROOF_FAIL_LIST
        jr Fail
FailCreate:
        ld a,PROOF_FAIL_CREATE
        jr Fail
FailBuildOrRun:
        ; ProofBuildAndRun leaves its more specific failure marker in A.
        jr Fail
FailEditor:
        ld a,0xE7
Fail:
        ld (PROOF_RESULT),a
        halt

ProofPath:
        .db     "/src/main.asm",0
ProofDirPath:
        .db     "/src",0
ProofExpectedList:
        .db     "main.asm",0x0A,"util.asm",0x0A,0
ProofDirCommand:
        .db     "DIR /src",0
ProofDirCommandEnd:
ProofNewPath:
        .db     "/src/new.asm",0
ProofBadCreatePath:
        .db     "/src/BAD.asm",0
ProofBuildPath:
        .db     "/project/build.asm",0
ProofOutputPath:
        .db     "/build/build.bin",0

ProofTarget:
        .db     SHL_ACTION_EDIT,SHL_TARGET_KIND_SOURCE_PATH
        .dw     ProofPath
        .db     0
ProofNewTarget:
        .db     SHL_ACTION_EDIT,SHL_TARGET_KIND_SOURCE_PATH
        .dw     ProofNewPath
        .db     0
ProofBuildTarget:
        .db     SHL_ACTION_ASM,SHL_TARGET_KIND_PROJECT_MAIN
        .dw     ProofBuildPath
        .db     0
ProofRunTarget:
        .db     SHL_ACTION_RUN,SHL_TARGET_KIND_PROJECT_OUTPUT
        .dw     ProofOutputPath
        .db     0

ProofEditorEvents:
        .db     "E",0
        .db     EDT_KEY_SAVE,EDT_KEY_MOD_CTRL
ProofQuitEvent:
        .db     EDT_KEY_QUIT,EDT_KEY_MOD_CTRL
ProofCreateEvents:
        .db     "N",0
        .db     EDT_KEY_SAVE,EDT_KEY_MOD_CTRL
        .db     EDT_KEY_QUIT,EDT_KEY_MOD_CTRL
