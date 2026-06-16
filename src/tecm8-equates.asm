; TECM8 shared assembly equates.
;
; This file emits no bytes. Include it once from each top-level program or
; proof before including TECM8 source modules.

TECM8_SOURCE_RECORD_BYTES          .equ    32
TECM8_SOURCE_RECORD_TEXT_MAX       .equ    TECM8_SOURCE_RECORD_BYTES - 1
TECM8_SOURCE_RECORD_LENGTH_MASK    .equ    0x1F
TECM8_SOURCE_RECORD_METADATA_MASK  .equ    0xE0
TECM8_SOURCE_RECORDS_PER_PAGE      .equ    16
TECM8_SECTOR_BYTES                 .equ    512

TECM8_EDITOR_NAV_PATH_LEN          .equ    64
TECM8_EDITOR_NAV_PAGE_BYTES        .equ    TECM8_SECTOR_BYTES
TECM8_EDITOR_NAV_WINDOW_BYTES      .equ    TECM8_SECTOR_BYTES * 4
TECM8_EDITOR_NAV_BACKED_PAGE_MAX   .equ    16
TECM8_EDITOR_NAV_WORKSPACE_BASE    .equ    0x3000
TECM8_EDITOR_NAV_CACHE_BASE        .equ    0x3000
TECM8_EDITOR_NAV_PAGE_BASE         .equ    0x3200
TECM8_EDITOR_NAV_NEXT_BASE         .equ    0x3400
TECM8_EDITOR_NAV_BACKUP_BASE       .equ    0x3600
TECM8_EDITOR_NAV_BLANK_BASE        .equ    0x3800
TECM8_EDITOR_NAV_PATH_BASE         .equ    0x3A00
TECM8_EDITOR_NAV_BACKUP_PATH_BASE  .equ    0x3A40
TECM8_EDITOR_NAV_WORKSPACE_END     .equ    0x3A80

EditorNavCachePageBuffer           .equ    TECM8_EDITOR_NAV_CACHE_BASE
EditorNavPageBuffer                .equ    TECM8_EDITOR_NAV_PAGE_BASE
EditorNavNextPageBuffer            .equ    TECM8_EDITOR_NAV_NEXT_BASE
EditorNavBackupPageBuffer          .equ    TECM8_EDITOR_NAV_BACKUP_BASE
EditorCreateBlankPageBuffer        .equ    TECM8_EDITOR_NAV_BLANK_BASE
EditorNavPathBuffer                .equ    TECM8_EDITOR_NAV_PATH_BASE
EditorNavBackupPathBuffer          .equ    TECM8_EDITOR_NAV_BACKUP_PATH_BASE

TECM8_GLCD_COLUMNS                 .equ    20
TECM8_GLCD_ROWS                    .equ    10
TECM8_GLCD_CELL_WIDTH              .equ    6
TECM8_GLCD_CELL_HEIGHT             .equ    6
TECM8_GLCD_TEXT_X                  .equ    6
TECM8_GLCD_Y_ORIGIN                .equ    2
TECM8_GLCD_BITMAP_ROW_BYTES        .equ    16
TECM8_GLCD_CELL_ROW_STRIDE         .equ    TECM8_GLCD_CELL_HEIGHT * TECM8_GLCD_BITMAP_ROW_BYTES
TECM8_MON3_GLCD_VPORT             .equ    0x0E13
TECM8_MON3_GLCD_TGBUF             .equ    0x13C0

TECM8_KEY_MOD_SHIFT                .equ    0x01
TECM8_KEY_MOD_CTRL                 .equ    0x02
TECM8_KEY_MOD_FN                   .equ    0x04
TECM8_KEY_MOD_ALT                  .equ    0x08
TECM8_KEY_MOD_CAPS                 .equ    0x10
