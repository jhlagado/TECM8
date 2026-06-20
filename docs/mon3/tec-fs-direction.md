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

## FAT32 Container Model

TEC-FS does not have to mean the whole SD card is unreadable to a PC. The
preferred compromise is to keep FAT32 as the outer PC-visible container and
store TEC-FS inside fixed image files:

```text
/TECFS00.IMG
/TECFS01.IMG
/TECFS02.IMG
...
```

The PC sees a normal FAT32 card containing image files. The TEC treats each
image file as a native TEC-FS volume once it knows the image start sector and
length. From that point on, the TEC reads and writes TEC-FS sectors directly
inside the selected image and does not need to implement FAT32 directories, long
filename records, general cluster allocation, or FAT update rules.

This gives most of the benefit of PC readability without dragging FAT32
complexity into MON3-light. The normal formatter should run on the TEC-1G: it
creates the MBR, creates one FAT32 partition, lays out as many fixed-size TEC-FS
image files as fit, and records their absolute start sectors and lengths.

The important constraint is contiguity. A normal FAT32 file is not guaranteed to
be physically contiguous on the card. If a `TECFSxx.IMG` file is fragmented, the TEC
cannot simply treat it as a linear block device unless it also implements FAT
cluster-chain traversal. The first design should avoid that:

- the TEC formatter creates each `TECFSxx.IMG` as a contiguous preallocated file
- the TEC formatter writes the FAT chains and root directory entries for the
  known fixed layout
- a PC utility can verify the images are still contiguous
- a PC utility can rebuild or replace an image if a PC later fragments it
- the TEC stores or discovers only the image start sector and image length

The standard locator should be explicit: a small locator sector or card header
records each image start sector, sector count, format version, and checksum.
The TEC should not need full FAT32 write support after the formatter has
created the known layout.

In the standard layout, image files act like DOS-style drives:

```text
0:  TECFS00.IMG
1:  TECFS01.IMG
2:  TECFS02.IMG
...
```

The active image is selected by number, and sector addressing is simple:

```text
absolute_sd_sector = image_start_sector[drive] + sector_inside_image
```

## Image Size

The current TEC-FS v1 fixed-slot layout needs about 8 MiB per virtual disk:

```text
16512 sectors * 512 bytes = 8,454,144 bytes
```

A FAT32-hosted `TECFSxx.IMG` can be larger. The standard size should be
128 MiB per image volume:

| Image size | Use |
| ---: | --- |
| 8 MiB | One compact TEC-FS disk. Small and easy to inspect. |
| 16 MiB | Generous first image size. |
| 64 MiB | Conservative test or small-card size. |
| 128 MiB | Standard TEC-FS image volume. Tidy, large enough, and still manageable on a Z80. |

FAT32 can hold files up to just under 4 GiB, but that is not a useful first
target. The SD card should instead be segmented into multiple 128 MiB TEC-FS
image volumes.

A 128 MiB image is:

```text
128 MiB = 134,217,728 bytes
        = 262,144 sectors of 512 bytes
        = 0x40000 sectors
```

Addressing a 128 MiB image needs 18 bits of sector number inside the image. The
clean design is still to use 32-bit sector numbers or byte offsets in file
records and tooling. On the TEC side, low-level calls can pass 32-bit sector
numbers as four bytes, while most file lengths and memory ranges can remain
16-bit because a TEC file is normally bounded by the Z80 address space.

A 4 GiB card or partition holds 32 nominal 128 MiB images before FAT32 and
directory overhead:

```text
4 GiB / 128 MiB = 32 image volumes
```

In practice, the formatter should reserve space for the MBR, FAT32 metadata,
root directory, locator table, and any small PC-visible helper files, so a
nominal 4 GiB card should be expected to hold 31 full 128 MiB TEC-FS images
unless the exact card capacity and overhead leave enough room for all 32.

## Allocation Block Size

The standard TEC-FS allocation block should be 4 KiB:

```text
4 KiB block = 8 sectors of 512 bytes
128 MiB image / 4 KiB = 32,768 allocation blocks
```

This follows the existing TECM8 virtual filesystem decision. It also maps well
to the editor source model:

```text
32-byte source record
512-byte sector = 16 source lines
4 KiB block     = 128 source lines
```

At 128 MiB, 4 KiB blocks remain compact. A bitmap allocator needs only 4 KiB to
represent the whole image:

```text
32,768 blocks = 32,768 bits = 4 KiB bitmap
```

An 8 KiB block size would halve allocation metadata, but it would also waste
more space for small source files, BASIC programs, project files, metadata,
notes, and backup files. Since TECM8 already uses 4 KiB blocks and 512-byte
editor pages, 4 KiB should remain the default unless later measurements prove a
larger block is needed.

## File Records And Long Names

A future TEC-FS should keep that spirit but improve the format. The file record
should be expanded so names are not cramped and TEC metadata is not hidden in
sidecar files or private headers.

Useful file-record fields include:

- long filename or path
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

A sensible first limit is 128 bytes for the name/path field. That is large
enough for readable virtual paths while still being easy to buffer, compare,
and scan on a Z80. It is also a convenient power-of-two size for fixed file
records or record extensions.

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

The current fixed-slot model is simple and debuggable. It avoids fragmentation
by giving each file a known home, but it wastes space because every slot must
reserve enough sectors for a maximum-size file.

A future layout can keep that controlled shape while improving allocation:

- card header at a known sector
- file record table at a known location
- file data in fixed extents
- optional free-extent table
- optional compaction handled by a PC utility

The important constraint is predictability. The TEC-side code should be able to
find records, load files, save memory ranges, delete entries, and rename entries
without complex allocation machinery.

Variable-length files are useful, especially once long names, source files,
assets, BASIC files, and saved states live together. They introduce a familiar
problem: deleted or resized files can leave gaps. The first implementation does
not need a full allocator. A practical early rule is:

- writing a new file uses a free record and a contiguous extent
- rewriting an existing file overwrites its current extent when it still fits
- rewriting with a larger size can either fail cleanly or allocate a new extent
- compaction/defragmentation is a PC utility job first

That keeps TEC-side code small while leaving room for better allocation later.
The filesystem should record enough extent information that a PC tool can pack,
unpack, check, and compact the image safely.

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
- create contiguous `TECFSxx.IMG` files
- verify `TECFSxx.IMG` contiguity
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
- compact or rebuild an image

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
- image start sector and length discovery
- compact error reporting
- optional compact TEC-FS record/file calls if they fit

The richer TEC-FS file manager, formatter, import/export tools, metadata editor,
and PC transfer logic should not be forced into fixed ROM. They can live in
banked ROM or host tooling.

MON3's current FAT32 loader remains useful as a compatibility path for ordinary
PC-prepared cards. TEC-FS inside `TECFSxx.IMG` image volumes is the richer
native storage system for serious TEC work.

## Direction

The direction should be:

1. Complete TEC-FS as the native filesystem.
2. Standardise on 128 MiB `TECFSxx.IMG` image volumes.
3. Standardise on 4 KiB allocation blocks inside each image.
4. Define the image locator and contiguity rules for FAT32-hosted cards.
5. Build the TEC-side formatter that writes the MBR, FAT32 partition, image
   files, and locator table.
6. Keep the existing SD/SPI routines where they are still correct.
7. Review Craig's original SD code and the later `sd_api` work for the cleanest
   block I/O base.
8. Modernise the file records.
9. Add 128-byte native path/name fields.
10. Add prefix-based virtual folders.
11. Keep the disk layout simple and predictable.
12. Start with contiguous extents and overwrite-in-place where possible.
13. Leave compaction and image rebuilding to the PC utility first.
14. Decide which minimal TEC-FS calls, if any, belong in fixed MON3-light ROM.
15. Move the full file manager and maintenance tools into banked ROM.
16. Build a PC utility for transfer, inspection, formatting, repair, contiguity
    checking, and image compaction.

That gives us a filesystem that feels designed for the TEC rather than borrowed
from somewhere else.
