; TECM8 expansion ROM physical bank 8: bounded binary loader and runner.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x08
EXP_VERSION       .equ    0x01

Tecm8ExpansionBank8Entry:
        cp RUN_SVC_RUN
        jp z,runArtifact
        ld a,RUN_ERR_UNKNOWN
        scf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
runArtifact:
        .rcignore definite_contract_violation "Initialization publishes all runner state through shared RAM; no incoming DE value remains live."
        call runInitialize
        .rcignore definite_contract_violation "Target validation consumes the shared target pointer; no incoming HL or flag value remains live."
        call runValidateTarget
        jp c,runBadTarget
        ld a,TFS_ARTIFACT_KIND_BINARY
        ld (TFS_PARAM_ARTIFACT_KIND),a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_LOAD_ARTIFACT
        jp c,runStorageError
        ld hl,(TFS_PARAM_ARTIFACT_LOAD_LO)
        ld (RUN_PARAM_LOAD_LO),hl
        ld de,(TFS_PARAM_ARTIFACT_SIZE_LO)
        ld (RUN_PARAM_BYTES_LO),de
        add hl,de
        ld (RUN_PARAM_END_LO),hl
        ld hl,(TFS_PARAM_ARTIFACT_RUN_LO)
        ld (RUN_PARAM_ENTRY_LO),hl
        call runValidateLoadedRange
        jp c,runBadRange
        ld hl,RUN_TRAMPOLINE_BASE
        ld (hl),0xCD
        inc hl
        ld de,(RUN_PARAM_ENTRY_LO)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),0xC9
        call RUN_TRAMPOLINE_BASE

runProgramReturned:
        ld a,(RUN_PARAM_RETURN_COUNT)
        inc a
        ld (RUN_PARAM_RETURN_COUNT),a
        ld a,(RUN_LOAD_MAX-0x10)
        ld (RUN_PARAM_MARKER),a
        xor a
        ld (RUN_PARAM_STATUS),a
        ld (RUN_PARAM_LAST_ERROR),a
        ld a,SHL_RESULT_OK
        ld (RUN_PARAM_RESULT_LO),a
        xor a
        ld (RUN_PARAM_RESULT_HI),a
        ld a,0x88
        or a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,H,L
runInitialize:
        ld a,EXP_BANK
        ld (RUN_PARAM_BANK),a
        ld a,EXP_VERSION
        ld (RUN_PARAM_VERSION),a
        xor a
        ld (RUN_PARAM_STATUS),a
        ld (RUN_PARAM_LAST_ERROR),a
        ld (RUN_PARAM_RESULT_LO),a
        ld (RUN_PARAM_RESULT_HI),a
        ld hl,RUN_STATE_BASE
        ld (hl),a
        ld de,RUN_STATE_BASE+1
        ld bc,0x0F
        ldir
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,H,L
runValidateTarget:
        ld hl,(RUN_PARAM_TARGET_LO)
        ld a,h
        or l
        scf
        ret z
        ld a,(hl)
        cp SHL_ACTION_RUN
        scf
        ret nz
        inc hl
        ld a,(hl)
        cp SHL_TARGET_KIND_PROJECT_OUTPUT
        scf
        ret nz
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,D,E,H,L
runValidateLoadedRange:
        ld hl,(RUN_PARAM_LOAD_LO)
        ld de,RUN_LOAD_MIN
        or a
        sbc hl,de
        ret c
        ld hl,(RUN_PARAM_END_LO)
        ld de,RUN_LOAD_MAX+1
        or a
        sbc hl,de
        ccf
        ret c
        ld hl,(RUN_PARAM_ENTRY_LO)
        ld de,(RUN_PARAM_LOAD_LO)
        or a
        sbc hl,de
        ret c
        ld hl,(RUN_PARAM_ENTRY_LO)
        ld de,(RUN_PARAM_END_LO)
        or a
        sbc hl,de
        ccf
        ret

runBadTarget:
        ld a,RUN_ERR_BAD_TARGET
        jr runPublishFileError
runStorageError:
        ld a,RUN_ERR_STORAGE
        jr runPublishFileError
runBadRange:
        ld a,RUN_ERR_BAD_RANGE
runPublishFileError:
        ld (RUN_PARAM_STATUS),a
        ld (RUN_PARAM_LAST_ERROR),a
        ld a,SHL_RESULT_FILE_ERROR
        ld (RUN_PARAM_RESULT_LO),a
        xor a
        ld (RUN_PARAM_RESULT_HI),a
        ld a,(RUN_PARAM_LAST_ERROR)
        scf
        ret

Tecm8ExpansionBank8Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
