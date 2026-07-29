# TecMate Monitor Launch Proof

This proof runs the fixed monitor's `launchExpansion` entry directly under the
Debug80 TEC-1G runtime. It verifies the installed-expansion path used by the
MON3/MON3Lite menu:

1. fixed monitor discovers the bank-0 `EXPR` header
2. bank 0 installs the expansion menu vector into monitor RAM
3. fixed monitor calls the installed menu vector through the bank-call path
4. bank 0 runs its TecMate demo entry chain
5. bank 0 returns to the caller-provided monitor return address

The installed-expansion case also verifies that the entry chain is visible as a
small runnable system: it writes the `TecMate ROM Shell` home screen,
`KEY:0000 JOY:00` input echo, and `POLL` status through the VDU/TMS9918 service
after the first input/update/render loop slice, reads the bank-6 input
snapshot, and touches the bank-2 TEC-FS mount state.

After that, the same runtime executes a RAM stub that calls `RST 10h` with
`C=TFS_MOUNT`. That verifies the generic MON3
service bridge calls the installed service vector and restores `SYS_CTRL` on
return.

The installed runtime then seeds a source catalogue entry and installs the
bank-5 sector simulation, writes `edit` into the shell command buffer, and
calls `SHL_RUN_COMMAND`. The proof verifies the resolved `/src/main.asm` target,
the 1536-byte editor workspace and three initial 32-byte records, cursor
line/column, clear dirty flag, `OK` result, visible source rows,
`Ln 01 Col 01 CLEAN Pg 1/1` status, and normal return through the service
bridge. It pauses the live Debug80 execution to observe the solid-block
character cursor, inserts a printable character, observes `DIRTY`, and verifies
the visible discard prompt. The last-run JSON records the clean reopened window
as `installed.editorWindow`. It then calls `SHL_RENDER_STATUS` and verifies the
shell status line contains exactly `EDIT`.

The same runtime later drives the ambitious editor workflow through the shell:
fifteen down-arrow events cross the first page boundary; Enter grows the source
to page two; printable input, left, Delete, Enter, and Backspace exercise
insert/delete/split/join; Ctrl-Up and Ctrl-Down traverse the two-page workspace;
Ctrl-S writes two source sectors followed by one metadata sector; Ctrl-Q/N
cancels discard; and Ctrl-Q/Y confirms it. The proof then reopens the file and
checks that saved `PAGEY` persisted while the later discarded `!` did not.

It then proves the complete self-hosted tool loop. The proof saves a five-record
program containing `REX`, runs `asm`, and verifies `BUILD` at source record 4.
Reopening `edit` lands at that record and column; the simulated key stream
changes it to `RET` and saves. A second `asm` emits
`3E 5A 32 F0 4F C9`, a `TMAP` source map, two artifact data writes, and two
artifact metadata writes through bank 2 and the bank-5 sector bridge. Finally,
`run` validates and loads the six-byte image at `4000h`, executes its marker
write at `4FF0h`, regains control after the program's `RET`, and returns safely
through the shell service bridge. The evidence is recorded as
`installed.buildWorkflow`.

The same installed runtime also seeds one TEC-FS catalogue slot, writes `dir`
into the shell command buffer, calls `SHL_RUN_COMMAND`, checks the bank-2
catalogue summary result, calls `SHL_RENDER_STATUS` to show `DIR`, and calls
`SHL_RENDER_RESULT` to show `OK`. The last-run JSON records the compact result
as `installed.shellDirResult` and the visible result status as
`installed.shellDirResultStatus`.

It then repeats `dir` with an inactive catalogue slot. That path must still
return `SHL_RESULT_OK`, publish a zero summary count, clear the first-entry
flag, and render `OK`. This proves an empty catalogue is not treated as a file
error.

It also repeats `dir` with a zero catalogue-buffer pointer. That path must
publish `SHL_RESULT_FILE_ERROR`, keep the compact TEC-FS error detail in the
result high byte, and render `FILE`. This proves the shell error path is
visible without adding a larger directory UI.

The runner uses the monitor D8 map to locate `launchExpansion` and the bank-0
D8 map to locate the installed menu provider, so the proof fails if discovery,
installation, vector launch, or bridge dispatch stops reaching the bank-0
service path.

The same runner also creates a runtime with no expansion image installed. That
case verifies the monitor keeps the menu and service vectors cleared, returns
through the missing-expansion path, leaves the bank-0 bootstrap trace untouched,
and makes an expansion `RST 10h` request fail with `A=FFh` instead of jumping
through a stale vector.
