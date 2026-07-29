# TecMate SD Workspace Demo

TecMate now has a ROM-resident, file-oriented editor path intended for a
practical Debug80 demonstration. It uses the project monitor, the 144 KiB
banked expansion ROM, the TMS9918 display, and a real FAT32 SD image containing
`VOLUME.TM8`; no host-loaded editor program is involved after the machine
starts.

Prepare all ROMs and a fresh demo image with:

```sh
npm run debug80:tecmate-workspace-image
```

The command creates:

```text
demos/debug80/tecmate-workspace-fat32.img
demos/debug80/tecmate-workspace-fat32.json
```

`debug80.json` refers to that image with a repository-relative path. Start the
`main` Debug80 target, reset the TEC-1G, and select **Expansion** from MON3.
Bank 0 mounts TEC-FS, selects the real bank-5 MON3 SD driver, and enters the
bank-4 editor directly when the monitor reports an SD card. `Ctrl-Q` returns
safely to the TecMate shell. If there is no SD card, the same expansion entry
falls back to the shell instead of entering the editor.

The initial image contains `/src/main.asm`, `/src/util.asm`, a hidden backup
fixture, a two-file `/project` build fixture, and an empty `/build` prefix.
The editor opens `/src/main.asm` on the first run. Later runs restore the last
file and cursor position from `/src/.tecmate.s`.

## Editor controls

| Key | Action |
| --- | --- |
| Arrows | Move the solid-block cursor |
| Enter | Split the current record |
| Backspace/Delete | Join or delete at record boundaries |
| Ctrl-S | Safely save the current file |
| Ctrl-O | Open the bounded `/src` chooser |
| Ctrl-N | Create and open a new `/src` file |
| Ctrl-A | Save the current buffer under a new `/src` name |
| Ctrl-R | Rename the current file within `/src` |
| Ctrl-G | Show compact on-machine help |
| Ctrl-Q | Quit; dirty buffers require confirmation |
| Escape | Cancel a chooser, name prompt, or recovery prompt |

The chooser shows at most the first 16 visible names returned in its bounded
256-byte list buffer. Dot-prefixed files are hidden. New, save-as, and rename
accept 1–27 characters from `a-z`, `0-9`, `.`, `_`, and `-`; uppercase input is
stored lowercase. These commands are deliberately confined to `/src`, and
rename cannot cross a TEC-FS prefix.

The editor holds three 512-byte pages: 48 fixed 32-byte records with 31 text
bytes per record. Files larger than that workspace are rejected by the
existing bounded source-loader contract. GLCD support remains optional; this
demo uses the TMS9918.

## Session and interrupted-save contract

The hidden `/src/.tecmate.s` file contains one 64-byte `TMS1` session record:

```text
magic, version, recovery flags, line, column, page, total lines,
path length, zero-terminated current path
```

A safe save derives a same-prefix hidden backup name. For example,
`/src/main.asm` uses `/src/.main.asm.b`. Before overwriting the source, TecMate:

1. copies every committed source page and its committed size to the backup;
2. writes a session record with `recovery pending`;
3. writes source data pages and then source metadata;
4. clears the recovery flag in a final session commit.

If an SD write fails after step 2, the editor leaves the buffer dirty and
reports a file error. On the next boot it offers `Restore last saved file?
Y/N`. Choosing `Y` loads the committed backup into the editor as a dirty
buffer; the next `Ctrl-S` restores it without overwriting that backup first.
Choosing `N` keeps the on-disk source and clears the pending marker.

## Automated acceptance

Run:

```sh
npm run proof:tecfs-mon3-file
```

The proof uses Debug80's real SD emulation and bank-5 MON3 file driver. It
performs raw lookup/load/save, then drives the booted editor through help, new,
save, save-as, rename, chooser-open, cursor/session restore, and clean return.
It deterministically fails the first source-sector write of a later save,
restarts, restores the committed backup, saves successfully, and continues
through directory, multi-file build, run, and debugger workflows. The host
then reopens the resulting volume and verifies the source, backup, created and
renamed files, binary, and map.

The fault injector is diagnostic RAM state in bank 5. A zero countdown—the
normal power-on value—has no effect on production writes.
