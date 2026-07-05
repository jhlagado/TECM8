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
small runnable system: it writes `TecMate` and `READY` through the VDU/TMS9918
service, reads the bank-6 input snapshot, and touches the bank-2 TEC-FS mount
state.

After that, the same runtime executes a RAM stub that calls `RST 10h` with
`C=TFS_MOUNT`. That verifies the generic MON3
service bridge calls the installed service vector and restores `SYS_CTRL` on
return.

The runner uses the monitor D8 map to locate `launchExpansion` and the bank-0
D8 map to locate the installed menu provider, so the proof fails if discovery,
installation, vector launch, or bridge dispatch stops reaching the bank-0
service path.

The same runner also creates a runtime with no expansion image installed. That
case verifies the monitor keeps the menu and service vectors cleared, returns
through the missing-expansion path, leaves the bank-0 bootstrap trace untouched,
and makes an expansion `RST 10h` request fail with `A=FFh` instead of jumping
through a stale vector.
