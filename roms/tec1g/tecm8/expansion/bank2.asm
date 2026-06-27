; TECM8 expansion ROM physical bank 2: TEC-FS service skeleton.

        .include "bank_ops.asmi"

        .org    0x8000

TECM8_EXPANSION_BANK          .equ    0x02
TECM8_EXPANSION_VERSION       .equ    0x01
TECFS_VOLUME_MIB              .equ    128
TECFS_BLOCK_BYTES             .equ    4096
TECFS_VOLUME_BLOCKS           .equ    32768

@Tecm8ExpansionBank2Entry:
        ld a,TECM8_EXPANSION_BANK
        ld (TECM8_DEMO_TRACE_2),a
        ret

        .org    0x8010
@tecfsMount:
        ld a,0x82
        ret

        .org    0x8020
@tecfsSelectVolume:
        ret

        .org    0x8030
@tecfsRead:
        ret

        .org    0x8040
@tecfsWrite:
        ret

        .org    0x8050
@tecfsLoadRange:
        ret

        .org    0x8060
@tecfsSaveRange:
        ret

        .org    0x80C0
@BankAbiNestedTarget:
        ld c,TECM8_BIOS_SYS_GET
        rst 10H
        ld (TECM8_ABI_TRACE_8),a
        ld a,0xB2
        ret

        .org    0x8100
@Tecm8ExpansionBank2Info:
        .db     "T","M","8",TECM8_EXPANSION_BANK,TECM8_EXPANSION_VERSION
