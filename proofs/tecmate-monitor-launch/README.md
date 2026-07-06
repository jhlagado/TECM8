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

The installed runtime then writes `edit` into the shell command buffer, calls
`SHL_RUN_COMMAND`, calls `SHL_RENDER_STATUS`, and verifies the TMS9918 status
line contains exactly `EDIT`. The last-run JSON records this as
`installed.shellCommandStatus`, which is used by the manual ROM demo guide.

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
