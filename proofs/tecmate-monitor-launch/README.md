# TecMate Monitor Launch Proof

This proof runs the fixed monitor's `launchExpansion` entry directly under the
Debug80 TEC-1G runtime. It verifies the path used by the MON3/MON3Lite menu:

1. fixed monitor discovers the bank-0 `EXPR` header
2. bank 0 installs the expansion menu vector into monitor RAM
3. fixed monitor calls the installed menu vector through the bank-call path
4. bank 0 runs its TecMate entry chain
5. bank 0 returns to the caller-provided monitor return address

The runner uses the monitor D8 map to locate `launchExpansion` and the bank-0
D8 map to locate the installed menu provider, so the proof fails if discovery,
installation, or vector launch stops reaching the bank-0 entry.
