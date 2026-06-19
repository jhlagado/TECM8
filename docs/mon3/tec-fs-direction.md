# TEC-FS: A Native Filesystem For The TEC-1G

TEC-FS should be understood as the continuation of the SD card filesystem work
already started for the TEC-1G. The point is not to imitate a desktop computer
filesystem. The point is to build a filesystem that suits the TEC: small,
predictable, easy to understand, and powerful enough for the way people
actually use the machine.

A TEC file is not just an anonymous stream of bytes. It usually has meaning in
relation to the machine. It may have a load address, an end address, a run
address, a file type, an expansion-memory flag, a timestamp, or a note about
what hardware it expects. A general-purpose PC filesystem does not naturally
understand any of that. TEC-FS can.

That is the strongest argument for TEC-FS. It can be designed around TEC
concepts instead of forcing the TEC to behave like a PC. Saving a memory range,
restoring a program, cataloguing games, storing BASIC files, managing tunes, or
preserving a full machine state can all be first-class operations.

The existing TEC-FS work already points in this direction. It has routines for
SD card access, formatting, file records, loading, saving, deleting, renaming,
timestamps, file types, and virtual disks. That is more like a real TEC file
manager than the MON3 disk loader, which is primarily useful for finding
existing files and loading them.

## File Records And Long Names

A future TEC-FS should keep that spirit but improve the format. The file record
should be expanded so names are not cramped and TEC metadata is not hidden in
sidecar files or private headers.

Useful file-record fields include:

- long filename
- file type
- load address
- end address or length
- run address
- expansion-memory flag
- executable flag
- timestamp
- required hardware
- checksum
- short description if space allows

Long names should be native. There is no reason to inherit old filename
restrictions. A file should be able to be called something readable, such as:

```text
GAMES/TEC INVADERS RGB.BIN
BASIC/NUMBER GUESSING GAME.BAS
SOURCE/MON3 LIGHT DISPLAY TEST.ASM
TUNES/INTRO THEME.TUN
```

There should be no 8.3 alias, no separate long-filename entry chain, and no
compatibility trick. The name is just a field in the file record.

## Virtual Folders

The same long-name field can also give us a simple directory-like system
without real directories. TEC-FS can remain flat internally, with every file
stored in one catalogue, while treating slashes in filenames as path
separators.

To show the contents of `GAMES/`, the file manager simply lists files whose
names begin with `GAMES/`. To move a file, it changes the prefix. To delete a
virtual folder, it deletes or moves all files with that prefix.

This gives most of the practical value of folders without the machinery of real
subdirectories. There are no directory sectors, no parent links, no recursive
traversal, and no special directory allocation rules. It is just string
filtering over a file catalogue. That is a good fit for a small Z80 system.

## Disk Layout

The current fixed-slot model is simple and debuggable. It wastes space, but
modern SD cards make that acceptable for a first native filesystem.

A future layout can keep that controlled shape while improving allocation:

- card header at a known sector
- file record table at a known location
- file data in fixed extents
- optional free-extent table
- optional compaction handled by a PC utility

The important constraint is predictability. The TEC-side code should be able to
find records, load files, save memory ranges, delete entries, and rename entries
without complex allocation machinery.

## TEC-Side User Model

The TEC-1G file manager may be used through a keypad, LCD, serial terminal,
GLCD, VDU, or menu system. The filesystem should support simple workflows:

- numbered file slots where useful
- filtering by file type
- shallow virtual folders by prefix
- save prompts that default to useful memory ranges
- load prompts that show load and run metadata
- BASIC, source, game, tune, data, and machine-state categories
- direct save and restore of memory ranges
- expansion-memory save support

The fixed ROM should not need to contain the full file manager UI. A compact
SD/TEC-FS service can be resident, while richer browse, import, export, format,
and maintenance tools can live in banked ROM.

## PC Access

The PC side is manageable. Instead of expecting the operating system to mount a
TEC-FS card directly, we write a TEC-FS management tool.

That tool can copy files onto a card, extract them, rename them, format cards,
inspect metadata, and map PC folders to TEC-FS path prefixes. On the PC, the
tool can present `GAMES/INVADERS.BIN` as a normal folder and file. On the TEC,
it remains a simple catalogue entry.

The first version can be command-line only. It should work with physical SD
cards and disk images, and support:

- format
- list
- copy file onto card
- copy file off card
- import folder
- export card
- rename
- delete
- edit metadata
- inspect file records
- check or repair
- map PC folders to TEC-FS path prefixes

This is a better split of responsibility. The TEC gets a small filesystem it
can realistically implement and maintain. The PC gets the heavier convenience
layer, where memory, speed, and user interface are not scarce.

## MON3-Light Relationship

The MON3 disk loader remains useful, but it is not the model for the long-term
TEC storage system. TEC-FS can become more powerful because it owns the format.
It can store exactly the metadata the TEC needs. It can have long names without
compatibility tricks. It can provide virtual folders without implementing a full
directory tree. It can make saving and loading memory ranges natural rather
than bolted on.

The MON3-light fixed ROM should provide the lowest practical storage services:

- SD initialisation
- card status
- 512-byte sector read
- 512-byte sector write
- compact error reporting
- optional compact TEC-FS record/file calls if they fit

The richer TEC-FS file manager, formatter, import/export tools, metadata editor,
and PC transfer logic should not be forced into fixed ROM. They can live in
banked ROM or host tooling.

MON3's current FAT32 loader remains useful as a compatibility path for ordinary
PC-prepared cards. TEC-FS is the richer native storage system for serious TEC
work.

## Direction

The direction should be:

1. Complete TEC-FS as the native filesystem.
2. Keep the existing SD/SPI routines where they are still correct.
3. Review Craig's original SD code and the later `sd_api` work for the cleanest
   block I/O base.
4. Modernise the file records.
5. Add long names.
6. Add prefix-based virtual folders.
7. Keep the disk layout simple and predictable.
8. Decide which minimal TEC-FS calls, if any, belong in fixed MON3-light ROM.
9. Move the full file manager and maintenance tools into banked ROM.
10. Build a PC utility for transfer, inspection, formatting, and repair.

That gives us a filesystem that feels designed for the TEC rather than borrowed
from somewhere else.
