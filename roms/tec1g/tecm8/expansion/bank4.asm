; TECM8 expansion ROM physical bank 4: interactive source editor.

        .include "bank_ops.asmi"

        .org    0x8000

EXP_BANK          .equ    0x04
EXP_VERSION       .equ    0x01

Tecm8ExpansionBank4Entry:
        cp EDT_SVC_OPEN
        jp z,editorOpenImpl
        cp EDT_SVC_RUN
        jp z,editorRunImpl
        cp EDT_SVC_STEP
        jp z,editorStepImpl
        cp EDT_SVC_BLINK
        jp z,editorBlinkImpl
        cp EDT_SVC_BOOT
        jp z,editorBootImpl
        cp GLC_SVC_INIT
        jp z,glcdUnsupported
        cp GLC_SVC_CLEAR
        jp z,glcdUnsupported
        cp GLC_SVC_PLOT
        jp z,glcdUnsupported
        jp glcdBoundaryEntryImpl

glcdInit:
        jp glcdUnsupported

glcdClear:
        jp glcdUnsupported

glcdPlot:
        jp glcdUnsupported

glcdBoundaryEntryImpl:
        ld a,EXP_BANK
        ld (GLC_PARAM_BANK),a
        ld a,EXP_VERSION
        ld (GLC_PARAM_VERSION),a
        ld a,GLC_FEATURE_BOUNDARY
        ld (GLC_PARAM_FEATURES),a
        xor a
        ld (GLC_PARAM_STATUS),a
        ld (GLC_PARAM_LAST_ERROR),a
        ld a,0x84
        or a
        ret

glcdUnsupported:
        ld a,GLC_ERR_UNSUPPORTED
        ld (GLC_PARAM_STATUS),a
        ld (GLC_PARAM_LAST_ERROR),a
        scf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorOpenImpl:
        call editorInitializeState
        call editorResolveProjectMain
        jp c,editorBadTarget
        call editorValidateTarget
        jp c,editorBadTarget
        call editorOwnTargetPath
        jp c,editorBadTarget
        ld hl,(TFS_PARAM_DRIVER_ADDR_LO)
        ld a,h
        cp TFS_MON3_FILE_DRIVER / 256
        jr nz,editorOpenResidentCatalog
        ld a,l
        cp TFS_MON3_FILE_DRIVER & 0xFF
        jr nz,editorOpenResidentCatalog
        ld hl,(EDT_PARAM_TARGET_LO)
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (TFS_PARAM_PATH_LO),de
        or a
        .expectout A,carry
        .rcignore definite_contract_violation "The source path is published through TFS parameter RAM; no caller DE/HL value is live after the bank call."
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_FIND_PATH
        jr nc,editorOpenResidentCatalog
        ld a,(TFS_PARAM_LAST_ERROR)
        cp TFS_ERR_NOT_FOUND
        jp nz,editorFileError
        or a
        .expectout A,carry
        .rcignore definite_contract_violation "Create consumes the source path from TFS parameter RAM; no caller DE/HL value is live after the bank call."
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_CREATE_SOURCE
        jp c,editorFileError
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_FIND_PATH
        jp c,editorFileError
editorOpenResidentCatalog:
editorLoadResolvedSource:
        ld hl,EDT_BUFFER_BASE
        ld (TFS_PARAM_LOAD_DEST_LO),hl
        ld hl,EDT_BUFFER_BYTES
        ld (TFS_PARAM_LOAD_BYTES_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_LOAD_SOURCE
        jp c,editorFileError
        ld hl,(TFS_PARAM_LOAD_LINES_LO)
        ld a,l
        or a
        jr nz,editorOpenHasLines
        inc a
editorOpenHasLines:
        ld (EDT_STATE_TOTAL_LINES),a
        ld (EDT_PARAM_LOADED_LINES_LO),a
        xor a
        ld (EDT_PARAM_LOADED_LINES_HI),a
        ld a,(TFS_PARAM_SOURCE_PAGE_COUNT)
        ld (EDT_STATE_LOADED_PAGES),a
        ld a,(TFS_PARAM_SOURCE_ALLOCATED_PAGES)
        ld (EDT_STATE_ALLOCATED_PAGES),a
        call editorApplyAssemblerDiagnostic
        call editorRenderWindow
        jp c,editorDisplayError
        ld a,SHL_RESULT_OK
        ld (EDT_PARAM_RESULT),a
        xor a
        ld (EDT_PARAM_STATUS),a
        ld (EDT_PARAM_LAST_ERROR),a
        ld a,0x84
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorRunImpl:
        call editorOpenImpl
        ld a,(EDT_PARAM_RESULT)
        cp SHL_RESULT_OK
        ret nz
editorRunLoop:
        ld a,(EDT_STATE_QUIT)
        or a
        jr nz,editorRunDone
        or a
        .expectout A,carry
        callBankService INP_BANK,INP_ENTRY,INP_SVC_READ_KEY
        jr c,editorInputError
        ld a,(INP_PARAM_EVENT)
        or a
        jr z,editorRunIdle
        call editorStepImpl
        jr editorRunLoop
editorRunIdle:
        call editorBlinkImpl
        jr editorRunLoop
editorRunDone:
        call editorCursorHide
        ld a,0x84
        or a
        ret

; Direct file-workspace entry used by the boot/demo path. Session restore can
; replace the default path before the editor loop without involving bank 0's
; command parser.
editorBootImpl:
        ld a,SHL_ACTION_EDIT
        ld (SHL_TARGET_ACTION),a
        ld a,SHL_TARGET_KIND_SOURCE_PATH
        ld (SHL_TARGET_KIND),a
        ld hl,EditorMainPath
        ld (SHL_TARGET_PATH_LO),hl
        xor a
        ld (SHL_TARGET_FLAGS),a
        ld hl,SHL_TARGET_DESC
        ld (EDT_PARAM_TARGET_LO),hl
        call editorOpenImpl
        ld a,(EDT_PARAM_RESULT)
        cp SHL_RESULT_OK
        ret nz
        call editorRestoreSession
        jp editorRunLoop

editorInputError:
        ld a,(INP_PARAM_LAST_ERROR)
        jp editorPublishError

.routine out A,zero clobbers sign,parity,halfCarry,B
editorApplyAssemblerDiagnostic:
        ld a,(ASM_PARAM_RESULT_LO)
        cp SHL_RESULT_BUILD_ERROR
        ret nz
        ld a,(ASM_PARAM_DIAG_LINE)
        ld b,a
        ld a,(EDT_STATE_TOTAL_LINES)
        cp b
        ret c
        ret z
        ld a,b
        and 0x0F
        ld (EDT_STATE_LINE),a
        ld a,b
        srl a
        srl a
        srl a
        srl a
        ld (EDT_STATE_PAGE),a
        ld a,(ASM_PARAM_DIAG_COLUMN)
        cp EDT_RECORD_DATA_BYTES
        jr c,editorApplyAssemblerColumnReady
        ld a,EDT_RECORD_DATA_BYTES-1
editorApplyAssemblerColumnReady:
        ld (EDT_STATE_COLUMN),a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,B,D,E,H,L
editorInitializeState:
        ld de,(EDT_PARAM_TARGET_LO)
        xor a
        ld hl,EDT_PARAM_STATUS
        ld b,EDT_PARAM_RESULT-EDT_PARAM_STATUS+1
editorInitializeParamsNext:
        ld (hl),a
        inc hl
        djnz editorInitializeParamsNext
        ld hl,EDT_STATE_BASE
        ld b,0x20
editorInitializeStateNext:
        ld (hl),a
        inc hl
        djnz editorInitializeStateNext
        ld a,EXP_BANK
        ld (EDT_PARAM_BANK),a
        ld a,EXP_VERSION
        ld (EDT_PARAM_VERSION),a
        ld hl,EDT_BUFFER_BASE
        ld (EDT_PARAM_BUFFER_LO),hl
        ld hl,EDT_BUFFER_BYTES
        ld (EDT_PARAM_BUFFER_BYTES_LO),hl
        ld (EDT_PARAM_TARGET_LO),de
        ld hl,EDT_WORK_BASE
        ld b,0x60
        xor a
editorInitializeWorkNext:
        ld (hl),a
        inc hl
        djnz editorInitializeWorkNext
        ld hl,EditorSessionPath
        ld de,EDT_SESSION_PATH_BUFFER
        ld bc,0x0010
        ldir
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorResolveProjectMain:
        ld hl,(EDT_PARAM_TARGET_LO)
        ld a,h
        or l
        scf
        ret z
        ld a,(hl)
        cp SHL_ACTION_EDIT
        scf
        ret nz
        inc hl
        ld a,(hl)
        cp SHL_TARGET_KIND_PROJECT_MAIN
        jr z,editorResolveDefaultMain
        cp SHL_TARGET_KIND_SOURCE_PATH
        scf
        ret nz
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        scf
        ret z
        or a
        ret
editorResolveDefaultMain:
        inc hl
        ld de,SHL_TARGET_PATH_BUFFER
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,EditorMainPath
        ld bc,SHL_TARGET_PATH_CAPACITY
        ldir
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,H,L
editorValidateTarget:
        ld hl,(EDT_PARAM_TARGET_LO)
        ld a,h
        or l
        scf
        ret z
        ld a,(hl)
        cp SHL_ACTION_EDIT
        scf
        ret nz
        inc hl
        ld a,(hl)
        cp SHL_TARGET_KIND_PROJECT_MAIN
        jr z,editorValidateTargetKind
        cp SHL_TARGET_KIND_SOURCE_PATH
        scf
        ret nz
editorValidateTargetKind:
        inc hl
        ld a,(hl)
        inc hl
        or (hl)
        scf
        ret z
        or a
        ret

; Copy the caller-owned path into the editor's stable 32-byte path buffer and
; repoint the descriptor. File chooser, save-as, rename, and session restore
; can then replace the current path without relying on shell command storage.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,D,E,H,L
editorOwnTargetPath:
        ld hl,(EDT_PARAM_TARGET_LO)
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld de,EDT_AUX_PATH_BUFFER
        ld b,SHL_TARGET_PATH_CAPACITY
        xor a
        ld (EDT_WORK_PATH_LEN),a
editorOwnTargetPathCopy:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr z,editorOwnTargetPathBuffered
        ld a,(EDT_WORK_PATH_LEN)
        inc a
        ld (EDT_WORK_PATH_LEN),a
        djnz editorOwnTargetPathCopy
        scf
        ret
editorOwnTargetPathBuffered:
        ld hl,EDT_AUX_PATH_BUFFER
        ld de,SHL_TARGET_PATH_BUFFER
        ld bc,SHL_TARGET_PATH_CAPACITY
        ldir
        ld hl,(EDT_PARAM_TARGET_LO)
        inc hl
        inc hl
        ld (hl),SHL_TARGET_PATH_BUFFER & 0xFF
        inc hl
        ld (hl),SHL_TARGET_PATH_BUFFER / 256
        or a
        ret

editorBadTarget:
        ld a,EDT_ERR_BAD_TARGET
        jr editorPublishError
editorFileError:
        ld a,(TFS_PARAM_LAST_ERROR)
        jr editorPublishError
editorDisplayError:
        ld a,SVC_ERR_UNKNOWN
editorPublishError:
        ld (EDT_PARAM_STATUS),a
        ld (EDT_PARAM_LAST_ERROR),a
        ld a,SHL_RESULT_FILE_ERROR
        ld (EDT_PARAM_RESULT),a
        ld a,0x84
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorStepImpl:
        call editorCursorHide
        ld a,(INP_PARAM_KEY)
        ld (EDT_STATE_LAST_KEY),a
        ld a,(INP_PARAM_MODIFIERS)
        ld (EDT_STATE_LAST_MODIFIERS),a
        ld a,(EDT_WORK_MODE)
        or a
        jp nz,editorWorkspaceStep
        ld a,(EDT_STATE_PROMPT)
        or a
        jp nz,editorStepPrompt
        ld a,(EDT_STATE_LAST_KEY)
        cp EDT_KEY_SAVE_AS
        jp z,editorBeginSaveAs
        cp EDT_KEY_HELP
        jp z,editorShowHelp
        cp EDT_KEY_NEW
        jp z,editorBeginNew
        cp EDT_KEY_OPEN
        jp z,editorOpenChooser
        cp EDT_KEY_RENAME
        jp z,editorBeginRename
        cp EDT_KEY_SAVE
        jp z,editorSave
        cp EDT_KEY_QUIT
        jp z,editorQuit
        cp EDT_KEY_UP
        jp z,editorMoveUp
        cp EDT_KEY_DOWN
        jp z,editorMoveDown
        cp EDT_KEY_LEFT
        jp z,editorMoveLeft
        cp EDT_KEY_RIGHT
        jp z,editorMoveRight
        cp EDT_KEY_BACKSPACE
        jp z,editorBackspace
        cp EDT_KEY_DELETE
        jp z,editorDelete
        cp EDT_KEY_ENTER
        jp z,editorSplit
        cp 0x20
        jp c,editorStepRender
        cp 0x7F
        jp nc,editorStepRender
        jp editorInsertPrintable

editorStepPrompt:
        ld a,(EDT_STATE_LAST_KEY)
        and 0xDF
        cp "Y"
        jr z,editorPromptYes
        cp "N"
        jr z,editorPromptNo
        jp editorRenderPrompt
editorPromptYes:
        xor a
        ld (EDT_STATE_PROMPT),a
        ld (EDT_PARAM_DIRTY_FLAGS),a
        ld (EDT_STATE_DIRTY_PAGES),a
        inc a
        ld (EDT_STATE_QUIT),a
        ld a,(EDT_STATE_DISCARD_CONFIRMS)
        inc a
        ld (EDT_STATE_DISCARD_CONFIRMS),a
        ld a,0x84
        or a
        ret
editorPromptNo:
        xor a
        ld (EDT_STATE_PROMPT),a
        ld a,(EDT_STATE_DISCARD_CANCELS)
        inc a
        ld (EDT_STATE_DISCARD_CANCELS),a
        jp editorRenderWindow

editorQuit:
        ld a,(EDT_PARAM_DIRTY_FLAGS)
        or a
        jr nz,editorQuitDirty
        call editorWriteSession
        jp c,editorFileError
        ld a,0x01
        ld (EDT_STATE_QUIT),a
        ld a,0x84
        or a
        ret
editorQuitDirty:
        ld a,0x01
        ld (EDT_STATE_PROMPT),a
        jp editorRenderPrompt

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorRequireClean:
        ld a,(EDT_PARAM_DIRTY_FLAGS)
        or a
        ret z
        ld hl,EditorSaveFirstText
        call editorShowStatusText
        scf
        ret

editorBeginNew:
        call editorRequireClean
        ret c
        ld a,EDT_MODE_NEW_NAME
        jr editorBeginNamePrompt

editorBeginSaveAs:
        ld a,EDT_MODE_SAVE_AS_NAME
        jr editorBeginNamePrompt

editorBeginRename:
        call editorRequireClean
        ret c
        ld a,EDT_MODE_RENAME_NAME
editorBeginNamePrompt:
        ld (EDT_WORK_MODE),a
        xor a
        ld (EDT_WORK_INPUT_LEN),a
        ld (EDT_INPUT_BUFFER),a
        jp editorRenderNamePrompt

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorOpenChooser:
        call editorRequireClean
        ret c
        ld hl,EditorSourcePrefix
        ld de,EDT_AUX_PATH_BUFFER
        ld bc,0x0005
        ldir
        ld hl,EDT_AUX_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        ld hl,EDT_LIST_BUFFER
        ld (TFS_PARAM_LIST_DEST_LO),hl
        ld hl,EDT_LIST_CAPACITY
        ld (TFS_PARAM_LIST_CAP_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_LIST_PATH
        jp c,editorFileError
        ld a,(TFS_PARAM_LIST_COUNT)
        or a
        jr z,editorOpenChooserEmpty
        ld (EDT_WORK_LIST_COUNT),a
        xor a
        ld (EDT_WORK_LIST_INDEX),a
        inc a
        ld (EDT_WORK_OPEN_COUNT),a
        ld a,EDT_MODE_OPEN
        ld (EDT_WORK_MODE),a
        jp editorRenderFileChooser
editorOpenChooserEmpty:
        ld hl,EditorNoFilesText
        jp editorShowStatusText

editorWorkspaceStep:
        ld a,(EDT_WORK_MODE)
        cp EDT_MODE_OPEN
        jp z,editorFileChooserStep
        cp EDT_MODE_HELP
        jp z,editorCloseOverlay
        cp EDT_MODE_RECOVER
        jp z,editorRecoveryPromptStep
        jp editorNamePromptStep

editorCloseOverlay:
        xor a
        ld (EDT_WORK_MODE),a
        jp editorRenderWindow

editorRecoveryPromptStep:
        ld a,(EDT_STATE_LAST_KEY)
        and 0xDF
        cp "Y"
        jr z,editorRecoveryRestore
        cp "N"
        jr z,editorRecoveryDismiss
        ld a,(EDT_STATE_LAST_KEY)
        cp EDT_KEY_ESCAPE
        jr z,editorRecoveryDismiss
        ld hl,EditorRecoveryPromptText
        jp editorShowStatusText
editorRecoveryDismiss:
        xor a
        ld (EDT_WORK_SESSION_FLAGS),a
        ld (EDT_WORK_MODE),a
        call editorWriteSession
        jp c,editorFileError
        jp editorRenderWindow
editorRecoveryRestore:
        call editorDeriveBackupPath
        jp c,editorFileError
        ld hl,EDT_AUX_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_FIND_PATH
        jp c,editorFileError
        ld hl,EDT_BUFFER_BASE
        ld (TFS_PARAM_LOAD_DEST_LO),hl
        ld hl,EDT_BUFFER_BYTES
        ld (TFS_PARAM_LOAD_BYTES_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_LOAD_SOURCE
        jp c,editorFileError
        ld a,(TFS_PARAM_LOAD_LINES_LO)
        or a
        jr nz,editorRecoveryHasLines
        inc a
editorRecoveryHasLines:
        ld (EDT_STATE_TOTAL_LINES),a
        ld (EDT_PARAM_LOADED_LINES_LO),a
        ld a,(TFS_PARAM_SOURCE_PAGE_COUNT)
        ld (EDT_STATE_LOADED_PAGES),a
        ld a,(TFS_PARAM_SOURCE_ALLOCATED_PAGES)
        ld (EDT_STATE_ALLOCATED_PAGES),a
        ld hl,SHL_TARGET_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_FIND_PATH
        jp c,editorFileError
        ld a,EDT_SESSION_FLAG_RECOVERY_PENDING+EDT_SESSION_FLAG_BUFFER_FROM_BACKUP
        ld (EDT_WORK_SESSION_FLAGS),a
        ld a,EDT_DIRTY_CHANGED
        ld (EDT_PARAM_DIRTY_FLAGS),a
        call editorMarkDirty
        xor a
        ld (EDT_WORK_MODE),a
        ld a,(EDT_WORK_RECOVERY_COUNT)
        inc a
        ld (EDT_WORK_RECOVERY_COUNT),a
        jp editorRenderWindow

editorFileChooserStep:
        ld a,(EDT_STATE_LAST_KEY)
        cp EDT_KEY_ESCAPE
        jp z,editorCloseOverlay
        cp EDT_KEY_QUIT
        jp z,editorCloseOverlay
        cp EDT_KEY_UP
        jr z,editorFileChooserUp
        cp EDT_KEY_DOWN
        jr z,editorFileChooserDown
        cp EDT_KEY_ENTER
        jp z,editorFileChooserOpen
        jp editorRenderFileChooser
editorFileChooserUp:
        ld a,(EDT_WORK_LIST_INDEX)
        or a
        jp z,editorRenderFileChooser
        dec a
        ld (EDT_WORK_LIST_INDEX),a
        jp editorRenderFileChooser
editorFileChooserDown:
        ld a,(EDT_WORK_LIST_INDEX)
        inc a
        ld b,a
        ld a,(EDT_WORK_LIST_COUNT)
        cp b
        jp z,editorRenderFileChooser
        ld a,b
        ld (EDT_WORK_LIST_INDEX),a
        jp editorRenderFileChooser
editorFileChooserOpen:
        call editorSelectedListName
        call editorBuildAuxPathFromName
        jp c,editorBadTarget
        call editorAdoptAuxPath
        xor a
        ld (EDT_WORK_MODE),a
        call editorReloadCurrentPath
        jp editorWriteSession

.routine out A,B,H,L clobbers zero,sign,parity,halfCarry
editorSelectedListName:
        ld hl,EDT_LIST_BUFFER
        ld a,(EDT_WORK_LIST_INDEX)
        or a
        jr z,editorSelectedListMeasure
        ld b,a
editorSelectedListSkip:
        ld a,(hl)
        inc hl
        cp 0x0A
        jr nz,editorSelectedListSkip
        djnz editorSelectedListSkip
editorSelectedListMeasure:
        push hl
        ld b,0
editorSelectedListMeasureNext:
        ld a,(hl)
        or a
        jr z,editorSelectedListMeasured
        cp 0x0A
        jr z,editorSelectedListMeasured
        inc hl
        inc b
        jr editorSelectedListMeasureNext
editorSelectedListMeasured:
        pop hl
        ret

editorNamePromptStep:
        ld a,(EDT_STATE_LAST_KEY)
        cp EDT_KEY_ESCAPE
        jp z,editorCloseOverlay
        cp EDT_KEY_QUIT
        jp z,editorCloseOverlay
        cp EDT_KEY_ENTER
        jp z,editorNamePromptComplete
        cp EDT_KEY_BACKSPACE
        jr z,editorNamePromptBackspace
        cp 0x20
        jp c,editorRenderNamePrompt
        cp 0x7F
        jp nc,editorRenderNamePrompt
        call editorValidateNameCharacter
        jp c,editorRenderNamePrompt
        ld b,a
        ld a,(EDT_WORK_INPUT_LEN)
        cp EDT_INPUT_CAPACITY
        jp nc,editorRenderNamePrompt
        ld e,a
        ld d,0
        ld hl,EDT_INPUT_BUFFER
        add hl,de
        ld a,b
        ld (hl),a
        inc hl
        ld (hl),0
        ld a,(EDT_WORK_INPUT_LEN)
        inc a
        ld (EDT_WORK_INPUT_LEN),a
        jp editorRenderNamePrompt
editorNamePromptBackspace:
        ld a,(EDT_WORK_INPUT_LEN)
        or a
        jp z,editorRenderNamePrompt
        dec a
        ld (EDT_WORK_INPUT_LEN),a
        ld e,a
        ld d,0
        ld hl,EDT_INPUT_BUFFER
        add hl,de
        ld (hl),0
        jp editorRenderNamePrompt

.routine out A,carry,zero clobbers sign,parity,halfCarry
editorValidateNameCharacter:
        ld a,(EDT_STATE_LAST_KEY)
        cp "A"
        jr c,editorValidateNameLowerReady
        cp "Z"+1
        jr nc,editorValidateNameLowerReady
        or 0x20
editorValidateNameLowerReady:
        cp "a"
        jr c,editorValidateNameDigit
        cp "z"+1
        jr c,editorValidateNameOk
editorValidateNameDigit:
        cp "0"
        jr c,editorValidateNamePunctuation
        cp "9"+1
        jr c,editorValidateNameOk
editorValidateNamePunctuation:
        cp "."
        jr z,editorValidateNameOk
        cp "_"
        jr z,editorValidateNameOk
        cp "-"
        jr z,editorValidateNameOk
        scf
        ret
editorValidateNameOk:
        or a
        ret

editorNamePromptComplete:
        ld a,(EDT_WORK_INPUT_LEN)
        or a
        jp z,editorRenderNamePrompt
        ld b,a
        ld hl,EDT_INPUT_BUFFER
        call editorBuildAuxPathFromName
        jp c,editorBadTarget
        ld a,(EDT_WORK_MODE)
        cp EDT_MODE_NEW_NAME
        jr z,editorCompleteNew
        cp EDT_MODE_SAVE_AS_NAME
        jr z,editorCompleteSaveAs
        jp editorCompleteRename

editorCompleteNew:
        ld hl,EDT_AUX_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_CREATE_SOURCE
        jp c,editorFileError
        call editorAdoptAuxPath
        ld a,(EDT_WORK_NEW_COUNT)
        inc a
        ld (EDT_WORK_NEW_COUNT),a
        xor a
        ld (EDT_WORK_MODE),a
        call editorReloadCurrentPath
        jp editorWriteSession

editorCompleteSaveAs:
        ld hl,EDT_AUX_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_CREATE_SOURCE
        jp c,editorFileError
        call editorAdoptAuxPath
        ld a,(EDT_WORK_SAVE_AS_COUNT)
        inc a
        ld (EDT_WORK_SAVE_AS_COUNT),a
        xor a
        ld (EDT_WORK_MODE),a
        ld a,EDT_DIRTY_CHANGED
        ld (EDT_PARAM_DIRTY_FLAGS),a
        jp editorSave

editorCompleteRename:
        ld hl,SHL_TARGET_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        ld hl,EDT_AUX_PATH_BUFFER
        ld (TFS_PARAM_AUX_PATH_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_RENAME_SOURCE
        jp c,editorFileError
        call editorAdoptAuxPath
        ld a,(EDT_WORK_RENAME_COUNT)
        inc a
        ld (EDT_WORK_RENAME_COUNT),a
        xor a
        ld (EDT_WORK_MODE),a
        call editorWriteSession
        jp c,editorFileError
        jp editorRenderWindow

.routine in B,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorBuildAuxPathFromName:
        ld a,b
        or a
        jr z,editorBuildAuxPathError
        cp EDT_INPUT_CAPACITY+1
        jr nc,editorBuildAuxPathError
        push hl
        push bc
        ld hl,EditorSourcePrefixSlash
        ld de,EDT_AUX_PATH_BUFFER
        ld bc,0x0005
        ldir
        pop bc
        pop hl
editorBuildAuxPathCopy:
        ld a,(hl)
        cp "A"
        jr c,editorBuildAuxPathNormalized
        cp "Z"+1
        jr nc,editorBuildAuxPathNormalized
        or 0x20
editorBuildAuxPathNormalized:
        ld (de),a
        inc hl
        inc de
        djnz editorBuildAuxPathCopy
        xor a
        ld (de),a
        ret
editorBuildAuxPathError:
        scf
        ret

.routine out A,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorAdoptAuxPath:
        ld hl,EDT_AUX_PATH_BUFFER
        ld de,SHL_TARGET_PATH_BUFFER
        ld b,SHL_TARGET_PATH_CAPACITY
        xor a
        ld (EDT_WORK_PATH_LEN),a
editorAdoptAuxPathNext:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr z,editorAdoptAuxPathDone
        push af
        ld a,(EDT_WORK_PATH_LEN)
        inc a
        ld (EDT_WORK_PATH_LEN),a
        pop af
        djnz editorAdoptAuxPathNext
editorAdoptAuxPathDone:
        ld hl,(EDT_PARAM_TARGET_LO)
        inc hl
        ld (hl),SHL_TARGET_KIND_SOURCE_PATH
        inc hl
        ld (hl),SHL_TARGET_PATH_BUFFER & 0xFF
        inc hl
        ld (hl),SHL_TARGET_PATH_BUFFER / 256
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorReloadCurrentPath:
        call editorCursorHide
        xor a
        ld hl,EDT_STATE_BASE
        ld b,0x0F
editorReloadClearState:
        ld (hl),a
        inc hl
        djnz editorReloadClearState
        ld (EDT_PARAM_DIRTY_FLAGS),a
        ld hl,SHL_TARGET_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_FIND_PATH
        jp c,editorFileError
        jp editorLoadResolvedSource

.routine out A,zero clobbers sign,parity,halfCarry,H,L
editorUsingRealStorage:
        ld hl,(TFS_PARAM_DRIVER_ADDR_LO)
        ld a,h
        cp TFS_MON3_FILE_DRIVER / 256
        ret nz
        ld a,l
        cp TFS_MON3_FILE_DRIVER & 0xFF
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorFindSession:
        ld hl,EDT_SESSION_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_FIND_PATH
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorEnsureSession:
        .rcignore definite_contract_violation "Session lookup publishes all state in TEC-FS parameter RAM; no incoming DE value remains live."
        call editorFindSession
        ret nc
        ld a,(TFS_PARAM_LAST_ERROR)
        cp TFS_ERR_NOT_FOUND
        ret nz
        ld hl,EDT_SESSION_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_CREATE_SOURCE
        ret c
        jp editorFindSession

; Persist the current file, caret, viewport-derived page, and recovery marker in
; a hidden two-record source file. The session sector is written and committed
; before the current source catalogue is reacquired.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorWriteSession:
        call editorUsingRealStorage
        jr z,editorWriteSessionReal
        or a
        ret
editorWriteSessionReal:
        ld hl,EDT_SESSION_BUFFER
        ld de,EDT_SESSION_BUFFER+1
        ld bc,EDT_PAGE_BYTES-1
        xor a
        ld (hl),a
        ldir
        ld hl,EditorSessionMagic
        ld de,EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_MAGIC
        ld bc,0x0004
        ldir
        ld a,EDT_SESSION_VERSION
        ld (EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_VERSION),a
        ld a,(EDT_WORK_SESSION_FLAGS)
        and EDT_SESSION_FLAG_RECOVERY_PENDING
        ld (EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_FLAGS),a
        ld a,(EDT_STATE_LINE)
        ld (EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_LINE),a
        ld a,(EDT_STATE_COLUMN)
        ld (EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_COLUMN),a
        ld a,(EDT_STATE_PAGE)
        ld (EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_PAGE),a
        ld a,(EDT_STATE_TOTAL_LINES)
        ld (EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_TOTAL_LINES),a
        ld a,(EDT_WORK_PATH_LEN)
        ld (EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_PATH_LEN),a
        ld c,a
        inc c
        ld b,0
        ld hl,SHL_TARGET_PATH_BUFFER
        ld de,EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_PATH
        ldir
        call editorEnsureSession
        jr c,editorSessionError
        xor a
        ld (TFS_PARAM_SOURCE_PAGE),a
        ld hl,EDT_SESSION_BUFFER
        ld (TFS_PARAM_LOAD_DEST_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_SAVE_SOURCE_PAGE
        jr c,editorSessionError
        ld hl,EDT_SESSION_RECORD_BYTES
        ld (TFS_PARAM_SOURCE_SIZE_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_COMMIT_SOURCE_META
        jr c,editorSessionError
        ld a,(EDT_WORK_SESSION_WRITE_COUNT)
        inc a
        ld (EDT_WORK_SESSION_WRITE_COUNT),a
        ld hl,SHL_TARGET_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_FIND_PATH
        ret
editorSessionError:
        ld a,(TFS_PARAM_LAST_ERROR)
        ld (EDT_WORK_LAST_IO_ERROR),a
        ld hl,SHL_TARGET_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_FIND_PATH
        ld a,(EDT_WORK_LAST_IO_ERROR)
        scf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorRestoreSession:
        call editorUsingRealStorage
        jr z,editorRestoreSessionReal
        or a
        ret
editorRestoreSessionReal:
        call editorFindSession
        jr nc,editorRestoreSessionLoad
        ld a,(TFS_PARAM_LAST_ERROR)
        cp TFS_ERR_NOT_FOUND
        jr nz,editorSessionError
        xor a
        ld (TFS_PARAM_STATUS),a
        ld (TFS_PARAM_LAST_ERROR),a
        ret
editorRestoreSessionLoad:
        ld hl,EDT_SESSION_BUFFER
        ld (TFS_PARAM_LOAD_DEST_LO),hl
        ld hl,EDT_BUFFER_BYTES
        ld (TFS_PARAM_LOAD_BYTES_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_LOAD_SOURCE
        jr c,editorSessionError
        ld hl,EDT_SESSION_BUFFER
        ld de,EditorSessionMagic
        ld b,0x04
editorRestoreSessionMagicNext:
        ld a,(de)
        cp (hl)
        jp nz,editorRestoreSessionInvalid
        inc de
        inc hl
        djnz editorRestoreSessionMagicNext
        ld a,(EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_VERSION)
        cp EDT_SESSION_VERSION
        jp nz,editorRestoreSessionInvalid
        ld a,(EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_PATH_LEN)
        or a
        jp z,editorRestoreSessionInvalid
        cp SHL_TARGET_PATH_CAPACITY
        jp nc,editorRestoreSessionInvalid
        ld b,a
        ld a,(EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_PATH)
        cp "/"
        jp nz,editorRestoreSessionInvalid
        ld a,(EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_FLAGS)
        and EDT_SESSION_FLAG_RECOVERY_PENDING
        ld (EDT_WORK_SESSION_FLAGS),a
        ld a,(EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_LINE)
        ld (EDT_WORK_RESTORE_LINE),a
        ld a,(EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_COLUMN)
        ld (EDT_WORK_RESTORE_COLUMN),a
        ld a,(EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_PATH_LEN)
        ld b,a
        inc b
        ld hl,EDT_SESSION_BUFFER+EDT_SESSION_OFFSET_PATH
        ld de,EDT_AUX_PATH_BUFFER
editorRestoreSessionPathCopy:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz editorRestoreSessionPathCopy
        call editorAdoptAuxPath
        call editorReloadCurrentPath
        ld a,(EDT_WORK_RESTORE_LINE)
        ld b,a
        ld a,(EDT_STATE_TOTAL_LINES)
        cp b
        jr c,editorRestoreSessionPositionDefault
        jr z,editorRestoreSessionPositionDefault
        ld a,b
        ld (EDT_STATE_LINE),a
        ld a,(EDT_WORK_RESTORE_COLUMN)
        ld (EDT_STATE_COLUMN),a
        call editorClampColumn
        call editorSyncPage
editorRestoreSessionPositionReady:
        ld a,(EDT_WORK_BOOT_RESTORE_COUNT)
        inc a
        ld (EDT_WORK_BOOT_RESTORE_COUNT),a
        ld a,(EDT_WORK_SESSION_FLAGS)
        and EDT_SESSION_FLAG_RECOVERY_PENDING
        jr nz,editorRestoreSessionRecovery
        jp editorRenderWindow
editorRestoreSessionPositionDefault:
        xor a
        ld (EDT_STATE_LINE),a
        ld (EDT_STATE_COLUMN),a
        ld (EDT_STATE_PAGE),a
        jr editorRestoreSessionPositionReady
editorRestoreSessionRecovery:
        ld a,EDT_MODE_RECOVER
        ld (EDT_WORK_MODE),a
        ld hl,EditorRecoveryPromptText
        jp editorShowStatusText
editorRestoreSessionInvalid:
        xor a
        ld (EDT_WORK_SESSION_FLAGS),a
        ld hl,SHL_TARGET_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_FIND_PATH
        ret

editorShowHelp:
        ld a,(EDT_WORK_HELP_COUNT)
        inc a
        ld (EDT_WORK_HELP_COUNT),a
        ld a,EDT_MODE_HELP
        ld (EDT_WORK_MODE),a
        call editorCursorHide
        ld de,0
        ld hl,0
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_CLEAR
        ret c
        ld hl,EditorHelpTitle
        ld a,0
        call editorWriteStringRow
        ld hl,EditorHelpLine1
        ld a,2
        call editorWriteStringRow
        ld hl,EditorHelpLine2
        ld a,3
        call editorWriteStringRow
        ld hl,EditorHelpLine3
        ld a,4
        call editorWriteStringRow
        ld hl,EditorHelpLine4
        ld a,5
        call editorWriteStringRow
        ld hl,EditorHelpLine5
        ld a,6
        call editorWriteStringRow
        ld hl,EditorHelpLine6
        ld a,7
        call editorWriteStringRow
        ld hl,EditorAnyKeyText
        jp editorShowStatusText

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorRenderFileChooser:
        call editorCursorHide
        ld de,0
        ld hl,0
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_CLEAR
        ret c
        ld hl,EditorOpenTitle
        xor a
        call editorWriteStringRow
        xor a
        ld (EDT_STATE_TEMP_0),a
        ld hl,EDT_LIST_BUFFER
        ld (EDT_WORK_LIST_PTR_LO),hl
editorRenderFileChooserNext:
        ld a,(EDT_STATE_TEMP_0)
        ld b,a
        ld a,(EDT_WORK_LIST_COUNT)
        cp b
        jp z,editorRenderFileChooserStatus
        ld hl,(EDT_WORK_LIST_PTR_LO)
        push hl
        ld b,0
editorRenderFileChooserMeasure:
        ld a,(hl)
        or a
        jr z,editorRenderFileChooserMeasured
        cp 0x0A
        jr z,editorRenderFileChooserMeasured
        inc hl
        inc b
        jr editorRenderFileChooserMeasure
editorRenderFileChooserMeasured:
        pop hl
        ld (TMS_PARAM_STRING_LO),hl
        ld a,b
        ld (TMS_PARAM_COUNT_LO),a
        xor a
        ld (TMS_PARAM_COUNT_HI),a
        ld a,(EDT_STATE_TEMP_0)
        inc a
        ld (TMS_PARAM_ROW),a
        ld a,2
        ld (TMS_PARAM_COL),a
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_SET_ROWCOL
        ret c
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_PUT_STRING_N
        ret c
        ld a,(EDT_STATE_TEMP_0)
        ld b,a
        ld a,(EDT_WORK_LIST_INDEX)
        cp b
        jr nz,editorRenderFileChooserAdvance
        ld a,(EDT_STATE_TEMP_0)
        inc a
        ld (TMS_PARAM_ROW),a
        xor a
        ld (TMS_PARAM_COL),a
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_SET_ROWCOL
        ret c
        ld a,">"
        ld (TMS_PARAM_VALUE),a
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_PUT_CHAR
        ret c
editorRenderFileChooserAdvance:
        ld hl,(EDT_WORK_LIST_PTR_LO)
editorRenderFileChooserAdvanceNext:
        ld a,(hl)
        inc hl
        or a
        jr z,editorRenderFileChooserAdvanceDone
        cp 0x0A
        jr nz,editorRenderFileChooserAdvanceNext
editorRenderFileChooserAdvanceDone:
        ld (EDT_WORK_LIST_PTR_LO),hl
        ld a,(EDT_STATE_TEMP_0)
        inc a
        ld (EDT_STATE_TEMP_0),a
        cp EDT_PAGE_RECORDS
        jp c,editorRenderFileChooserNext
editorRenderFileChooserStatus:
        ld hl,EditorOpenStatusText
        jp editorShowStatusText

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorRenderNamePrompt:
        ld hl,EDT_UI_LINE_BUFFER
        ld b,0x20
        xor a
editorRenderNamePromptClear:
        ld (hl),a
        inc hl
        djnz editorRenderNamePromptClear
        ld a,(EDT_WORK_MODE)
        cp EDT_MODE_NEW_NAME
        ld hl,EditorNewPromptText
        jr z,editorRenderNamePromptPrefix
        cp EDT_MODE_SAVE_AS_NAME
        ld hl,EditorSaveAsPromptText
        jr z,editorRenderNamePromptPrefix
        ld hl,EditorRenamePromptText
editorRenderNamePromptPrefix:
        ld de,EDT_UI_LINE_BUFFER
editorRenderNamePromptPrefixNext:
        ld a,(hl)
        or a
        jr z,editorRenderNamePromptInput
        ld (de),a
        inc hl
        inc de
        jr editorRenderNamePromptPrefixNext
editorRenderNamePromptInput:
        ld hl,EDT_INPUT_BUFFER
editorRenderNamePromptInputNext:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,editorRenderNamePromptInputNext
        ld hl,EDT_UI_LINE_BUFFER
        jp editorShowStatusText

.routine in A,HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorWriteStringRow:
        ld (TMS_PARAM_STRING_LO),hl
        ld (TMS_PARAM_ROW),a
        xor a
        ld (TMS_PARAM_COL),a
        or a
        .expectout A,carry
        .rcignore definite_contract_violation "The string pointer and coordinates are already published in TMS parameter RAM; PUT_STRING does not consume the prior DE/HL values."
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_SET_ROWCOL
        ret c
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_PUT_STRING
        ret

.routine in HL out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorShowStatusText:
        ld (TMS_PARAM_STRING_LO),hl
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_STATUS_LINE
        ret

editorMoveUp:
        ld a,(EDT_STATE_LAST_MODIFIERS)
        and EDT_KEY_MOD_CTRL
        jp nz,editorPageUp
        ld a,(EDT_STATE_LINE)
        or a
        jp z,editorStepRender
        dec a
        ld (EDT_STATE_LINE),a
        call editorClampColumn
        call editorSyncPage
        jp editorRenderWindow

editorMoveDown:
        ld a,(EDT_STATE_LAST_MODIFIERS)
        and EDT_KEY_MOD_CTRL
        jp nz,editorPageDown
        ld a,(EDT_STATE_LINE)
        inc a
        ld b,a
        ld a,(EDT_STATE_TOTAL_LINES)
        cp b
        jp z,editorStepRender
        ld a,b
        ld (EDT_STATE_LINE),a
        call editorClampColumn
        call editorSyncPage
        jp editorRenderWindow

editorMoveLeft:
        ld a,(EDT_STATE_COLUMN)
        or a
        jp z,editorStepRender
        dec a
        ld (EDT_STATE_COLUMN),a
        jp editorStepRender

editorMoveRight:
        call editorCurrentLength
        ld b,a
        ld a,(EDT_STATE_COLUMN)
        cp b
        jp nc,editorStepRender
        inc a
        ld (EDT_STATE_COLUMN),a
        jp editorStepRender

editorPageUp:
        ld a,(EDT_STATE_PAGE)
        or a
        jp z,editorStepRender
        dec a
        ld (EDT_STATE_PAGE),a
        call editorLineFromPageAndRow
        call editorClampColumn
        jp editorRenderWindow

editorPageDown:
        ld a,(EDT_STATE_PAGE)
        inc a
        ld b,a
        ld a,(EDT_STATE_LOADED_PAGES)
        cp b
        jp z,editorStepRender
        ld a,b
        ld (EDT_STATE_PAGE),a
        call editorLineFromPageAndRow
        call editorClampColumn
        jp editorRenderWindow

.routine out A,zero clobbers sign,parity,halfCarry,B
editorLineFromPageAndRow:
        ld a,(EDT_STATE_LINE)
        and 0x0F
        ld b,a
        ld a,(EDT_STATE_PAGE)
        rlca
        rlca
        rlca
        rlca
        add a,b
        ld b,a
        ld a,(EDT_STATE_TOTAL_LINES)
        cp b
        jr nc,editorLineFromPageInRange
        dec a
        jr editorLineFromPageStore
editorLineFromPageInRange:
        ld a,b
editorLineFromPageStore:
        ld (EDT_STATE_LINE),a
        ret

editorInsertPrintable:
        call editorCurrentLength
        cp 0x1F
        jp z,editorLineFull
        ld (EDT_STATE_TEMP_0),a
        call editorRecordAddressCurrent
        ld a,(hl)
        and 0xE0
        ld (EDT_STATE_TEMP_1),a
        ld a,(EDT_STATE_TEMP_0)
        ld b,a
        ld a,(EDT_STATE_COLUMN)
        ld c,a
editorInsertShiftNext:
        ld a,b
        cp c
        jr z,editorInsertWrite
        push bc
        call editorRecordAddressCurrent
        ld c,b
        ld b,0x00
        add hl,bc
        ld a,(hl)
        inc hl
        ld (hl),a
        pop bc
        dec b
        jr editorInsertShiftNext
editorInsertWrite:
        call editorRecordAddressCurrent
        inc hl
        ld a,(EDT_STATE_COLUMN)
        ld e,a
        ld d,0x00
        add hl,de
        ld a,(EDT_STATE_LAST_KEY)
        ld (hl),a
        call editorRecordAddressCurrent
        ld a,(EDT_STATE_TEMP_0)
        inc a
        ld b,a
        ld a,(EDT_STATE_TEMP_1)
        or b
        ld (hl),a
        ld a,(EDT_STATE_COLUMN)
        inc a
        ld (EDT_STATE_COLUMN),a
        call editorMarkDirty
        jp editorRenderWindow

editorBackspace:
        ld a,(EDT_STATE_COLUMN)
        or a
        jp z,editorJoinPrevious
        dec a
        ld (EDT_STATE_COLUMN),a
        call editorDeleteCharacter
        call editorMarkDirty
        jp editorRenderWindow

editorDelete:
        call editorCurrentLength
        ld b,a
        ld a,(EDT_STATE_COLUMN)
        cp b
        jr c,editorDeleteAtCursor
        ld a,(EDT_STATE_LINE)
        inc a
        ld b,a
        ld a,(EDT_STATE_TOTAL_LINES)
        cp b
        jp z,editorStepRender
        ld a,b
        ld (EDT_STATE_LINE),a
        jp editorJoinPrevious
editorDeleteAtCursor:
        call editorDeleteCharacter
        call editorMarkDirty
        jp editorRenderWindow

.routine out A,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorDeleteCharacter:
        call editorCurrentLength
        ld (EDT_STATE_TEMP_0),a
        call editorRecordAddressCurrent
        ld a,(hl)
        and 0xE0
        ld (EDT_STATE_TEMP_1),a
        ld a,(EDT_STATE_TEMP_0)
        ld b,a
        ld a,(EDT_STATE_COLUMN)
        inc a
        ld c,a
editorDeleteShiftNext:
        ld a,c
        cp b
        jr nc,editorDeleteShiftDone
        push bc
        call editorRecordAddressCurrent
        ld e,c
        ld d,0x00
        add hl,de
        inc hl
        ld a,(hl)
        dec hl
        ld (hl),a
        pop bc
        inc c
        jr editorDeleteShiftNext
editorDeleteShiftDone:
        call editorRecordAddressCurrent
        ld a,(EDT_STATE_TEMP_0)
        ld e,a
        ld d,0x00
        add hl,de
        xor a
        ld (hl),a
        call editorRecordAddressCurrent
        ld a,(EDT_STATE_TEMP_0)
        dec a
        ld b,a
        ld a,(EDT_STATE_TEMP_1)
        or b
        ld (hl),a
        ret

editorSplit:
        ld a,(EDT_STATE_TOTAL_LINES)
        cp EDT_BUFFER_RECORDS
        jp z,editorBufferFull
        call editorCurrentLength
        ld (EDT_STATE_TEMP_0),a
        ld a,(EDT_STATE_COLUMN)
        ld (EDT_STATE_TEMP_1),a
        call editorRecordAddressCurrent
        ld a,(hl)
        and 0xE0
        ld (EDT_STATE_TEMP_2),a
        ld a,(EDT_STATE_TOTAL_LINES)
        ld (EDT_STATE_TEMP_0+3),a
editorSplitShiftRecord:
        ld a,(EDT_STATE_TEMP_0+3)
        ld b,a
        ld a,(EDT_STATE_LINE)
        cp b
        jr z,editorSplitShiftDone
        ld a,b
        call editorRecordAddress
        ex de,hl
        ld a,b
        dec a
        call editorRecordAddress
        ld bc,0x0020
        ldir
        ld a,(EDT_STATE_TEMP_0+3)
        dec a
        ld (EDT_STATE_TEMP_0+3),a
        jr editorSplitShiftRecord
editorSplitShiftDone:
        call editorRecordAddressCurrent
        ld a,(EDT_STATE_TEMP_1)
        ld b,a
        ld a,(EDT_STATE_TEMP_2)
        or b
        ld (hl),a
        inc hl
        ld a,(EDT_STATE_TEMP_1)
        ld e,a
        ld d,0x00
        add hl,de
        ld b,0x1F
        ld a,(EDT_STATE_TEMP_1)
        ld c,a
        ld a,b
        sub c
        ld b,a
        xor a
editorSplitClearCurrent:
        ld (hl),a
        inc hl
        djnz editorSplitClearCurrent
        ld a,(EDT_STATE_LINE)
        inc a
        call editorRecordAddress
        push hl
        inc hl
        ld a,(EDT_STATE_TEMP_1)
        ld e,a
        ld d,0x00
        add hl,de
        ex de,hl
        pop hl
        inc hl
        ex de,hl
        ld a,(EDT_STATE_TEMP_0)
        ld b,a
        ld a,(EDT_STATE_TEMP_1)
        ld c,a
        ld a,b
        sub c
        ld c,a
        ld b,0x00
        ld a,c
        or a
        jr z,editorSplitTailCopied
        ldir
editorSplitTailCopied:
        ld a,(EDT_STATE_LINE)
        inc a
        call editorRecordAddress
        ld a,(EDT_STATE_TEMP_0)
        ld b,a
        ld a,(EDT_STATE_TEMP_1)
        ld c,a
        ld a,b
        sub c
        ld (hl),a
        ld a,(EDT_STATE_TOTAL_LINES)
        inc a
        ld (EDT_STATE_TOTAL_LINES),a
        ld (EDT_PARAM_LOADED_LINES_LO),a
        ld a,(EDT_STATE_LINE)
        inc a
        ld (EDT_STATE_LINE),a
        xor a
        ld (EDT_STATE_COLUMN),a
        ld a,(EDT_STATE_SPLIT_COUNT)
        inc a
        ld (EDT_STATE_SPLIT_COUNT),a
        call editorMarkDirty
        call editorSyncPage
        jp editorRenderWindow

editorJoinPrevious:
        ld a,(EDT_STATE_LINE)
        or a
        jp z,editorStepRender
        call editorCurrentLength
        ld (EDT_STATE_TEMP_1),a
        ld a,(EDT_STATE_LINE)
        dec a
        call editorRecordAddress
        ld a,(hl)
        and 0x1F
        ld (EDT_STATE_TEMP_0),a
        ld b,a
        ld a,(EDT_STATE_TEMP_1)
        add a,b
        cp 0x20
        jp nc,editorLineFull
        ld a,(EDT_STATE_LINE)
        call editorRecordAddress
        inc hl
        push hl
        ld a,(EDT_STATE_LINE)
        dec a
        call editorRecordAddress
        push hl
        inc hl
        ld a,(EDT_STATE_TEMP_0)
        ld e,a
        ld d,0x00
        add hl,de
        ex de,hl
        pop hl
        ld a,(hl)
        and 0xE0
        ld (EDT_STATE_TEMP_2),a
        pop hl
        ld a,(EDT_STATE_TEMP_1)
        ld c,a
        ld b,0x00
        ld a,c
        or a
        jr z,editorJoinTextCopied
        ldir
editorJoinTextCopied:
        ld a,(EDT_STATE_LINE)
        dec a
        call editorRecordAddress
        ld a,(EDT_STATE_TEMP_0)
        ld b,a
        ld a,(EDT_STATE_TEMP_1)
        add a,b
        ld b,a
        ld a,(EDT_STATE_TEMP_2)
        or b
        ld (hl),a
        ld a,(EDT_STATE_LINE)
        ld (EDT_STATE_TEMP_2),a
editorJoinShiftNext:
        ld a,(EDT_STATE_TEMP_2)
        inc a
        ld b,a
        ld a,(EDT_STATE_TOTAL_LINES)
        cp b
        jr z,editorJoinShiftDone
        ld a,b
        call editorRecordAddress
        push hl
        ld a,(EDT_STATE_TEMP_2)
        call editorRecordAddress
        ex de,hl
        pop hl
        ld bc,0x0020
        ldir
        ld a,(EDT_STATE_TEMP_2)
        inc a
        ld (EDT_STATE_TEMP_2),a
        jr editorJoinShiftNext
editorJoinShiftDone:
        ld a,(EDT_STATE_TOTAL_LINES)
        dec a
        ld (EDT_STATE_TOTAL_LINES),a
        ld (EDT_PARAM_LOADED_LINES_LO),a
        call editorRecordAddress
        ld b,0x20
        xor a
editorJoinClearTail:
        ld (hl),a
        inc hl
        djnz editorJoinClearTail
        ld a,(EDT_STATE_LINE)
        dec a
        ld (EDT_STATE_LINE),a
        ld a,(EDT_STATE_TEMP_0)
        ld (EDT_STATE_COLUMN),a
        ld a,(EDT_STATE_JOIN_COUNT)
        inc a
        ld (EDT_STATE_JOIN_COUNT),a
        call editorMarkDirty
        call editorSyncPage
        jp editorRenderWindow

editorBufferFull:
        ld a,EDT_ERR_BUFFER_FULL
        jr editorEditError
editorLineFull:
        ld a,EDT_ERR_LINE_FULL
editorEditError:
        ld (EDT_PARAM_LAST_ERROR),a
        ld (EDT_PARAM_STATUS),a
        jp editorRenderWindow

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorDeriveBackupPath:
        ld hl,SHL_TARGET_PATH_BUFFER
        ld (EDT_WORK_LIST_PTR_LO),hl
editorDeriveBackupFindSlash:
        ld a,(hl)
        or a
        jr z,editorDeriveBackupPrefixReady
        cp "/"
        jr nz,editorDeriveBackupFindNext
        inc hl
        ld (EDT_WORK_LIST_PTR_LO),hl
        dec hl
editorDeriveBackupFindNext:
        inc hl
        jr editorDeriveBackupFindSlash
editorDeriveBackupPrefixReady:
        ld hl,(EDT_WORK_LIST_PTR_LO)
        ld de,SHL_TARGET_PATH_BUFFER
        or a
        sbc hl,de
        ld b,l
        ld hl,SHL_TARGET_PATH_BUFFER
        ld de,EDT_AUX_PATH_BUFFER
        ld c,b
        ld b,0
        ldir
        ld a,"."
        ld (de),a
        inc de
        ld hl,(EDT_WORK_LIST_PTR_LO)
        ld b,0
editorDeriveBackupNameNext:
        ld a,(hl)
        or a
        jr z,editorDeriveBackupSuffix
        ld (de),a
        inc hl
        inc de
        inc b
        ld a,b
        cp TFS_CATALOG_NAME_BYTES-2
        jr nc,editorDeriveBackupError
        jr editorDeriveBackupNameNext
editorDeriveBackupSuffix:
        ld a,"."
        ld (de),a
        inc de
        ld a,"b"
        ld (de),a
        inc de
        xor a
        ld (de),a
        ret
editorDeriveBackupError:
        ld a,TFS_ERR_BAD_PATH
        ld (TFS_PARAM_LAST_ERROR),a
        scf
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorEnsureBackup:
        ld hl,EDT_AUX_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        or a
        .expectout A,carry
        .rcignore definite_contract_violation "Backup lookup consumes the path from TEC-FS parameter RAM; no incoming DE value remains live."
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_FIND_PATH
        ret nc
        ld a,(TFS_PARAM_LAST_ERROR)
        cp TFS_ERR_NOT_FOUND
        ret nz
        ld hl,EDT_AUX_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        or a
        .expectout A,carry
        .rcignore definite_contract_violation "Backup creation consumes the path from TEC-FS parameter RAM; no prior DE value remains live."
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_CREATE_SOURCE
        ret c
        ld hl,EDT_AUX_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_FIND_PATH
        ret

; Copy every page from the last committed source into its hidden .b file
; before the editor overwrites any source sector.
.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorBackupCommittedFile:
        call editorDeriveBackupPath
        ret c
        xor a
        ld (EDT_WORK_BACKUP_PAGE),a
editorBackupCommittedNext:
        ld a,(EDT_WORK_BACKUP_PAGE)
        ld b,a
        ld a,(EDT_STATE_ALLOCATED_PAGES)
        cp b
        jr z,editorBackupCommittedDataDone
        ld hl,SHL_TARGET_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_FIND_PATH
        ret c
        ld a,(TFS_PARAM_ENTRY_SIZE_0)
        ld (EDT_WORK_COMMITTED_SIZE_LO),a
        ld a,(TFS_PARAM_ENTRY_SIZE_1)
        ld (EDT_WORK_COMMITTED_SIZE_HI),a
        ld a,(EDT_WORK_BACKUP_PAGE)
        ld (TFS_PARAM_SOURCE_PAGE),a
        ld hl,EDT_BACKUP_BUFFER
        ld (TFS_PARAM_LOAD_DEST_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_LOAD_SOURCE_PAGE
        ret c
        call editorEnsureBackup
        ret c
        ld a,(EDT_WORK_BACKUP_PAGE)
        ld (TFS_PARAM_SOURCE_PAGE),a
        ld hl,EDT_BACKUP_BUFFER
        ld (TFS_PARAM_LOAD_DEST_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_SAVE_SOURCE_PAGE
        ret c
        ld a,(EDT_WORK_BACKUP_PAGE)
        inc a
        ld (EDT_WORK_BACKUP_PAGE),a
        jr editorBackupCommittedNext
editorBackupCommittedDataDone:
        call editorEnsureBackup
        ret c
        ld a,(EDT_WORK_COMMITTED_SIZE_LO)
        ld (TFS_PARAM_SOURCE_SIZE_LO),a
        ld a,(EDT_WORK_COMMITTED_SIZE_HI)
        ld (TFS_PARAM_SOURCE_SIZE_HI),a
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_COMMIT_SOURCE_META
        ret c
        ld hl,SHL_TARGET_PATH_BUFFER
        ld (TFS_PARAM_PATH_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_FIND_PATH
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorPrepareSafeSave:
        ld a,(EDT_WORK_SESSION_FLAGS)
        and EDT_SESSION_FLAG_BUFFER_FROM_BACKUP
        jr nz,editorPrepareSafeSaveSession
        call editorBackupCommittedFile
        ret c
editorPrepareSafeSaveSession:
        ld a,EDT_SESSION_FLAG_RECOVERY_PENDING
        ld (EDT_WORK_SESSION_FLAGS),a
        jp editorWriteSession

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorSave:
        ld a,(EDT_PARAM_DIRTY_FLAGS)
        or a
        jp z,editorRenderWindow
        call editorUsingRealStorage
        jr nz,editorSavePrepared
        call editorPrepareSafeSave
        jp c,editorFileError
editorSavePrepared:
        call editorUpdateGeometry
        xor a
        ld (EDT_STATE_TEMP_0),a
editorSaveNextPage:
        ld a,(EDT_STATE_TEMP_0)
        ld b,a
        ld a,(EDT_STATE_LOADED_PAGES)
        cp b
        jr z,editorSaveDataDone
        ld a,b
        ld (TFS_PARAM_SOURCE_PAGE),a
        add a,a
        add a,0x60
        ld h,a
        ld l,0x00
        ld (TFS_PARAM_LOAD_DEST_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_SAVE_SOURCE_PAGE
        jp c,editorFileError
        ld a,(EDT_STATE_TEMP_0)
        inc a
        ld (EDT_STATE_TEMP_0),a
        jr editorSaveNextPage
editorSaveDataDone:
        ld a,(EDT_STATE_LOADED_PAGES)
        ld b,a
        ld a,(EDT_STATE_ALLOCATED_PAGES)
        cp b
        jr nc,editorSaveNoGrowth
        ld a,b
        ld (EDT_STATE_ALLOCATED_PAGES),a
        ld (TFS_PARAM_SOURCE_ALLOCATED_PAGES),a
        ld a,(EDT_STATE_GROWTH_COUNT)
        inc a
        ld (EDT_STATE_GROWTH_COUNT),a
editorSaveNoGrowth:
        ld a,(EDT_STATE_TOTAL_LINES)
        ld l,a
        ld h,0x00
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld (TFS_PARAM_SOURCE_SIZE_LO),hl
        or a
        .expectout A,carry
        callBankService TFS_BANK,TFS_ENTRY,TFS_SVC_COMMIT_SOURCE_META
        jp c,editorFileError
        xor a
        ld (EDT_PARAM_DIRTY_FLAGS),a
        ld (EDT_STATE_DIRTY_PAGES),a
        ld (EDT_PARAM_STATUS),a
        ld (EDT_PARAM_LAST_ERROR),a
        ld (EDT_WORK_SESSION_FLAGS),a
        call editorWriteSession
        jp c,editorFileError
        ld a,(EDT_STATE_SAVE_COUNT)
        inc a
        ld (EDT_STATE_SAVE_COUNT),a
        jp editorRenderWindow

.routine out A,zero clobbers sign,parity,halfCarry,B
editorMarkDirty:
        ld a,EDT_DIRTY_CHANGED
        ld (EDT_PARAM_DIRTY_FLAGS),a
        call editorUpdateGeometry
        ld a,(EDT_STATE_LOADED_PAGES)
        ld b,a
        ld a,0x01
editorMarkDirtyMask:
        dec b
        jr z,editorMarkDirtyStore
        add a,a
        inc a
        jr editorMarkDirtyMask
editorMarkDirtyStore:
        ld (EDT_STATE_DIRTY_PAGES),a
        ret

.routine out A,zero clobbers sign,parity,halfCarry
editorUpdateGeometry:
        ld a,(EDT_STATE_TOTAL_LINES)
        add a,0x0F
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        or a
        jr nz,editorUpdateGeometryStore
        inc a
editorUpdateGeometryStore:
        ld (EDT_STATE_LOADED_PAGES),a
        ret

.routine out A,zero clobbers sign,parity,halfCarry
editorSyncPage:
        ld a,(EDT_STATE_LINE)
        rrca
        rrca
        rrca
        rrca
        and 0x0F
        ld (EDT_STATE_PAGE),a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,B,H,L
editorClampColumn:
        call editorCurrentLength
        ld b,a
        ld a,(EDT_STATE_COLUMN)
        cp b
        ret c
        ld a,b
        ld (EDT_STATE_COLUMN),a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,H,L
editorCurrentLength:
        call editorRecordAddressCurrent
        ld a,(hl)
        and 0x1F
        ret

.routine out A,H,L clobbers zero,sign,parity,halfCarry
editorRecordAddressCurrent:
        ld a,(EDT_STATE_LINE)
        jp editorRecordAddress

.routine in A out A,H,L clobbers zero,sign,parity,halfCarry
editorRecordAddress:
        ld l,a
        ld h,0x00
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        add a,0x60
        ld h,a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorRenderWindow:
        call editorCursorHide
        ld de,0x0000
        ld hl,0x0000
        or a
        .expectout A,carry
        .rcignore definite_contract_violation "The clear service consumes scratch zero values only; no DE/HL value is live after the bank call."
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_CLEAR
        ret c
        xor a
        ld (TMS_PARAM_ROW),a
        ld (TMS_PARAM_COL),a
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_SET_ROWCOL
        ret c
        ld hl,(EDT_PARAM_TARGET_LO)
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (TMS_PARAM_STRING_LO),de
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_PUT_STRING
        ret c
        ld a,(EDT_STATE_PAGE)
        rlca
        rlca
        rlca
        rlca
        ld (EDT_PARAM_FIRST_LINE_LO),a
        xor a
        ld (EDT_PARAM_FIRST_LINE_HI),a
        ld (EDT_STATE_TEMP_0),a
editorRenderNextLine:
        ld a,(EDT_STATE_TEMP_0)
        cp EDT_PAGE_RECORDS
        jr z,editorRenderStatus
        ld b,a
        ld a,(EDT_PARAM_FIRST_LINE_LO)
        add a,b
        ld b,a
        ld a,(EDT_STATE_TOTAL_LINES)
        cp b
        jr z,editorRenderStatus
        ld a,b
        call editorRecordAddress
        ld a,(hl)
        and 0x1F
        ld (TMS_PARAM_COUNT_LO),a
        xor a
        ld (TMS_PARAM_COUNT_HI),a
        inc hl
        ld (TMS_PARAM_STRING_LO),hl
        ld a,(EDT_STATE_TEMP_0)
        inc a
        ld (TMS_PARAM_ROW),a
        xor a
        ld (TMS_PARAM_COL),a
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_SET_ROWCOL
        ret c
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_PUT_STRING_N
        ret c
        ld a,(EDT_STATE_TEMP_0)
        inc a
        ld (EDT_STATE_TEMP_0),a
        jr editorRenderNextLine
editorRenderStatus:
        call editorBuildStatus
        ld hl,EDT_STATUS_BUFFER
        ld (TMS_PARAM_STRING_LO),hl
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_STATUS_LINE
        ret c
        call editorPublishCursorParams
        jp editorCursorShow

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorRenderPrompt:
        call editorCursorHide
        ld hl,EditorDiscardPromptText
        ld de,EDT_STATUS_BUFFER
        ld bc,EditorDiscardPromptTextEnd-EditorDiscardPromptText
        ldir
        ld hl,EDT_STATUS_BUFFER
        ld (TMS_PARAM_STRING_LO),hl
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_STATUS_LINE
        ret

.routine out A,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorBuildStatus:
        ld hl,EditorStatusTemplate
        ld de,EDT_STATUS_BUFFER
        ld bc,EditorStatusTemplateEnd-EditorStatusTemplate
        ldir
        ld a,(EDT_STATE_LINE)
        inc a
        ld de,EDT_STATUS_BUFFER+3
        call editorByteToTwoDigits
        ld a,(EDT_STATE_COLUMN)
        inc a
        ld de,EDT_STATUS_BUFFER+10
        call editorByteToTwoDigits
        ld a,(EDT_PARAM_DIRTY_FLAGS)
        or a
        jr z,editorBuildStatusPage
        ld hl,EditorDirtyText
        ld de,EDT_STATUS_BUFFER+13
        ld bc,0x0005
        ldir
editorBuildStatusPage:
        ld a,(EDT_STATE_PAGE)
        inc a
        add a,"0"
        ld (EDT_STATUS_BUFFER+22),a
        ld a,(EDT_STATE_LOADED_PAGES)
        add a,"0"
        ld (EDT_STATUS_BUFFER+24),a
        ret

.routine in A,DE out A,B,D,E clobbers zero,sign,parity,halfCarry
editorByteToTwoDigits:
        ld b,"0"
editorByteToTwoDigitsNext:
        cp 10
        jr c,editorByteToTwoDigitsStore
        sub 10
        inc b
        jr editorByteToTwoDigitsNext
editorByteToTwoDigitsStore:
        push af
        ld a,b
        ld (de),a
        inc de
        pop af
        add a,"0"
        ld (de),a
        ret

.routine out A,zero clobbers sign,parity,halfCarry,H,L
editorPublishCursorParams:
        ld a,(EDT_STATE_LINE)
        ld (EDT_PARAM_CURSOR_LINE_LO),a
        xor a
        ld (EDT_PARAM_CURSOR_LINE_HI),a
        ld a,(EDT_STATE_COLUMN)
        ld (EDT_PARAM_CURSOR_COLUMN),a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorCursorShow:
        ld a,(EDT_STATE_CURSOR_VISIBLE)
        or a
        ret nz
        call editorCurrentLength
        ld b,a
        ld a,(EDT_STATE_COLUMN)
        cp b
        jr nc,editorCursorShowBlank
        call editorRecordAddressCurrent
        inc hl
        ld a,(EDT_STATE_COLUMN)
        ld e,a
        ld d,0x00
        add hl,de
        ld a,(hl)
        jr editorCursorShowSave
editorCursorShowBlank:
        ld a,VDU_BLANK_CHAR
editorCursorShowSave:
        ld (EDT_STATE_CURSOR_CHAR),a
        call editorSetVduCursorCell
        ld a,EDT_CURSOR_BLOCK_CHAR
        ld (TMS_PARAM_VALUE),a
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_PUT_CHAR
        ret c
        call editorSetVduCursorCell
        ld a,0x01
        ld (EDT_STATE_CURSOR_VISIBLE),a
        xor a
        ld (EDT_STATE_BLINK_LO),a
        ld (EDT_STATE_BLINK_HI),a
        ld a,0x84
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorCursorHide:
        ld a,(EDT_STATE_CURSOR_VISIBLE)
        or a
        ret z
        .rcignore definite_contract_violation "Cursor coordinates are published through TMS parameter RAM; no caller DE/HL value is live across this helper."
        call editorSetVduCursorCell
        ld a,(EDT_STATE_CURSOR_CHAR)
        ld (TMS_PARAM_VALUE),a
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_PUT_CHAR
        ret c
        call editorSetVduCursorCell
        xor a
        ld (EDT_STATE_CURSOR_VISIBLE),a
        ld a,0x84
        or a
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorSetVduCursorCell:
        ld a,(EDT_STATE_LINE)
        and 0x0F
        inc a
        ld (TMS_PARAM_ROW),a
        ld a,(EDT_STATE_COLUMN)
        ld (TMS_PARAM_COL),a
        or a
        .expectout A,carry
        callBankService VDU_BANK,VDU_ENTRY,VDU_SVC_SET_ROWCOL
        ret

.routine out A,carry,zero clobbers sign,parity,halfCarry,B,C,D,E,H,L
editorBlinkImpl:
        ld hl,(EDT_STATE_BLINK_LO)
        inc hl
        ld (EDT_STATE_BLINK_LO),hl
        ld a,h
        cp 0x04
        jr c,editorBlinkDone
        xor a
        ld (EDT_STATE_BLINK_LO),a
        ld (EDT_STATE_BLINK_HI),a
        ld a,(EDT_STATE_CURSOR_VISIBLE)
        or a
        jp z,editorCursorShow
        jp editorCursorHide
editorBlinkDone:
        ld a,0x84
        or a
        ret

editorStepRender:
        jp editorRenderWindow

EditorStatusTemplate:
        .db     "Ln 00 Col 00 CLEAN Pg 0/0",0
EditorStatusTemplateEnd:
EditorDirtyText:
        .db     "DIRTY"
EditorDiscardPromptText:
        .db     "Discard changes? Y/N",0
EditorDiscardPromptTextEnd:
EditorSaveFirstText:
        .db     "Save/discard changes first",0
EditorNoFilesText:
        .db     "No source files in /src",0
EditorSourcePrefix:
        .db     "/src",0
EditorSourcePrefixSlash:
        .db     "/src/"
EditorOpenTitle:
        .db     "Open /src",0
EditorOpenStatusText:
        .db     "Up/Down Enter  Esc cancel",0
EditorNewPromptText:
        .db     "New /src/",0
EditorSaveAsPromptText:
        .db     "Save as /src/",0
EditorRenamePromptText:
        .db     "Rename /src/",0
EditorHelpTitle:
        .db     "TecMate editor keys",0
EditorHelpLine1:
        .db     "Arrows     move cursor",0
EditorHelpLine2:
        .db     "Ctrl-S     safe save",0
EditorHelpLine3:
        .db     "Ctrl-O/N   open / new",0
EditorHelpLine4:
        .db     "Ctrl-A     save as",0
EditorHelpLine5:
        .db     "Ctrl-R     rename",0
EditorHelpLine6:
        .db     "Ctrl-Q/G   quit / help",0
EditorAnyKeyText:
        .db     "Any key returns",0
EditorRecoveryPromptText:
        .db     "Restore last saved file? Y/N",0
EditorSessionMagic:
        .db     "TMS1"
EditorSessionPath:
        .db     "/src/.tecmate.s",0
EditorMainPath:
        .db     "/src/main.asm",0
        .ds     SHL_TARGET_PATH_CAPACITY-14

Tecm8ExpansionBank4Info:
        .db     "T","M","8",EXP_BANK,EXP_VERSION
