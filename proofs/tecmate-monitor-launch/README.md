# TecMate Monitor Launch Proof

This proof runs the fixed monitor's `launchTecMate` entry directly under the
Debug80 TEC-1G runtime. It verifies the path used by the MON3/MON3Lite menu:

1. fixed monitor selects expansion physical bank 0
2. fixed monitor jumps to `8000h`
3. bank 0 runs its TecMate entry chain
4. bank 0 returns to the caller-provided monitor return address

The runner uses the monitor D8 map to locate `launchTecMate`, so the proof fails
if the menu launcher symbol disappears or stops reaching the bank-0 entry.
