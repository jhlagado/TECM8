const { existsSync } = require('node:fs');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');

test('TEC-FS bank proof artifacts are wired into the repository', () => {
  assert.equal(existsSync(resolve(root, 'proofs/tecfs-bank/tecfs-bank-proof.asm')), true);
  assert.equal(existsSync(resolve(root, 'tools/run-tecfs-bank-proof.ts')), true);
});

test('package check runs the TEC-FS bank proof', () => {
  const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));
  assert.equal(pkg.scripts['proof:tecfs-bank'], 'node --experimental-strip-types tools/run-tecfs-bank-proof.ts');
  assert.match(pkg.scripts.check, /npm run proof:tecfs-bank/);
});

test('TEC-FS bank proof covers runtime volume selection in sector translation', () => {
  const proof = readFileSync(resolve(root, 'proofs/tecfs-bank/tecfs-bank-proof.asm'), 'utf8');
  const runner = readFileSync(resolve(root, 'tools/run-tecfs-bank-proof.ts'), 'utf8');
  const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-banked-service-abi.md'), 'utf8');

  assert.match(proof, /ld a,0x1F[\s\S]*ld a,TFS_SVC_SELECT_VOLUME[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp TFS_ERR_BAD_VOLUME[\s\S]*ld a,\(TFS_PARAM_ACTIVE_VOLUME\)[\s\S]*cp 0x1E/);
  assert.match(proof, /ld a,0x1D[\s\S]*ld a,TFS_SVC_SELECT_VOLUME[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*ld a,TFS_SVC_MAP_BLOCK[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp 0x74[\s\S]*ld a,TFS_SVC_TRANSLATE_SECTOR[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp 0x74/);
  assert.match(runner, /active TEC-FS volume/);
  assert.match(runner, /assertEqual\(params\[0\], 0x1d, 'active TEC-FS volume'\)/);
  assert.match(runner, /assertEqual\(params\[1\], 0x1d, 'last requested TEC-FS volume'\)/);
  assert.match(runner, /assertEqual\(params\[16\], 0x74, 'TEC-FS mapped sector byte 2'\)/);
  assert.match(doc, /leaves the previous active\s+volume\s+unchanged/);
});

test('TEC-FS bank proof covers installable sector bridge dispatch', () => {
  const proof = readFileSync(resolve(root, 'proofs/tecfs-bank/tecfs-bank-proof.asm'), 'utf8');
  const runner = readFileSync(resolve(root, 'tools/run-tecfs-bank-proof.ts'), 'utf8');
  const bank5 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank5.asm'), 'utf8');
  const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-banked-service-abi.md'), 'utf8');

  assert.match(proof, /ld a,0x05[\s\S]*ld \(TFS_PARAM_DRIVER_BANK\),a[\s\S]*ld hl,TFS_SECTOR_BRIDGE[\s\S]*ld \(TFS_PARAM_DRIVER_ADDR_LO\),hl/);
  assert.match(proof, /ld a,TFS_SVC_READ[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp 0x85[\s\S]*ld a,\(0x6000\)[\s\S]*cp TFS_BRIDGE_READ_MARKER/);
  assert.match(proof, /ld a,TFS_SVC_WRITE[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp 0x85/);
  assert.match(proof, /ld a,0x7F[\s\S]*farCall 0x05,TFS_SECTOR_BRIDGE[\s\S]*jp nc,FailDriverHook[\s\S]*cp SVC_ERR_UNKNOWN[\s\S]*ld a,\(TFS_PARAM_STATUS\)[\s\S]*cp 0x5A[\s\S]*ld a,\(TFS_PARAM_LAST_ERROR\)[\s\S]*cp 0xA5/);
  assert.match(runner, /assertEqual\(params\[29\], 0x05, 'TEC-FS driver bank'\)/);
  assert.match(runner, /assertEqual\(params\[31\], 0x80, 'TEC-FS driver address high byte'\)/);
  assert.match(bank5, /@Tecm8ExpansionBank5Entry:[\s\S]*cp TFS_DRIVER_OP_READ[\s\S]*jp z,tecfsSectorBridgeRead[\s\S]*cp TFS_DRIVER_OP_WRITE/);
  assert.match(bank5, /ld a,SVC_ERR_UNKNOWN\s+scf\s+ret/);
  assert.match(bank5, /tecfsSectorBridgeRead:[\s\S]*ld a,TFS_BRIDGE_READ_MARKER[\s\S]*ld \(hl\),a/);
  assert.match(doc, /Monitor-Sector Bridge/);
  assert.match(doc, /Unknown bridge operation selectors return `SVC_ERR_UNKNOWN`/);
});

test('TEC-FS bank proof reads a catalog-described first file sector', () => {
  const proof = readFileSync(resolve(root, 'proofs/tecfs-bank/tecfs-bank-proof.asm'), 'utf8');
  const runner = readFileSync(resolve(root, 'tools/run-tecfs-bank-proof.ts'), 'utf8');

  assert.match(proof, /ld a,TFS_ENTRY_STATUS_ACTIVE[\s\S]*ld \(0x6280\+TFS_CATALOG_OFFSET_STATUS\),a[\s\S]*ld a,TFS_SVC_DECODE_CATALOG[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*jp c,FailFileRead/);
  assert.match(proof, /ld a,\(TFS_PARAM_ENTRY_FIRST_BLOCK_LO\)[\s\S]*ld \(TFS_PARAM_BLOCK_INDEX_LO\),a[\s\S]*ld a,\(TFS_PARAM_ENTRY_FIRST_BLOCK_HI\)[\s\S]*ld \(TFS_PARAM_BLOCK_INDEX_HI\),a/);
  assert.match(proof, /ld a,TFS_SVC_MAP_BLOCK[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*ld a,TFS_SVC_TRANSLATE_SECTOR[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*ld hl,0x6001[\s\S]*ld a,TFS_SVC_READ/);
  assert.match(proof, /ld a,\(0x6001\)[\s\S]*cp TFS_BRIDGE_READ_MARKER/);
  assert.match(runner, /TEC-FS file read translated sector byte 0/);
  assert.match(runner, /TEC-FS file read copied sector marker/);
});

test('TEC-FS bank proof covers locator format and read services', () => {
  const proof = readFileSync(resolve(root, 'proofs/tecfs-bank/tecfs-bank-proof.asm'), 'utf8');
  const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-banked-service-abi.md'), 'utf8');
  const bank2 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank2.asm'), 'utf8');

  assert.match(proof, /ld a,TFS_SVC_FORMAT_LOCATOR[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp 0x82/);
  assert.match(proof, /ld a,TFS_SVC_READ_LOCATOR[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp 0x82/);
  assert.match(proof, /ld a,TFS_SVC_FORMAT_META_RECORD[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp 0x82[\s\S]*cp TFS_META_MAGIC_0[\s\S]*cp TFS_FILE_PROJECT/);
  assert.match(proof, /ld a,TFS_SVC_PATCH_META_RECORD[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp 0x82[\s\S]*cp TFS_FILE_GAME/);
  assert.match(proof, /ld a,TFS_SVC_DECODE_CATALOG[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp 0x82[\s\S]*ld a,\(TFS_PARAM_ENTRY_FILE_ID\)[\s\S]*cp 0x21/);
  assert.match(proof, /ld a,TFS_SVC_SUMMARIZE_CATALOG[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*ld a,\(TFS_PARAM_SUMMARY_COUNT_LO\)[\s\S]*cp 0x01/);
  assert.match(proof, /ld a,TFS_SVC_NEXT_CATALOG[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*ld hl,\(TFS_PARAM_BUFFER_LO\)[\s\S]*ld de,0x62C0[\s\S]*sbc hl,de/);
  assert.match(proof, /ld a,TFS_SVC_DECODE_CATALOG[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*ld a,\(TFS_PARAM_ENTRY_FILE_ID\)[\s\S]*cp 0x22[\s\S]*ld a,\(TFS_PARAM_ENTRY_FILE_TYPE\)[\s\S]*cp TFS_FILE_BINARY/);
  assert.match(proof, /ld a,TFS_SVC_SUMMARIZE_CATALOG[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*ld a,\(TFS_PARAM_SUMMARY_FLAGS\)[\s\S]*or a/);
  assert.match(proof, /ld a,TFS_SVC_DECODE_CATALOG[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*jp nc,FailDecodeCatalog[\s\S]*cp TFS_ERR_BAD_CATALOG/);
  assert.match(proof, /cp TFS_META_HW_TMS9918\+TFS_META_HW_JOYSTICK/);
  assert.match(proof, /cp TFS_ERR_BAD_LOCATOR/);
  assert.match(bank2, /cp TFS_SVC_FORMAT_LOCATOR[\s\S]*jp z,tecfsFormatLocatorImpl/);
  assert.match(bank2, /cp TFS_SVC_READ_LOCATOR[\s\S]*jp z,tecfsReadLocatorImpl/);
  assert.match(bank2, /cp TFS_SVC_FORMAT_META_RECORD[\s\S]*jp z,tecfsFormatMetaRecordImpl/);
  assert.match(bank2, /cp TFS_SVC_PATCH_META_RECORD[\s\S]*jp z,tecfsPatchMetaRecordImpl/);
  assert.match(bank2, /cp TFS_SVC_DECODE_CATALOG[\s\S]*jp z,tecfsDecodeCatalogImpl/);
  assert.match(bank2, /cp TFS_SVC_SUMMARIZE_CATALOG[\s\S]*jp z,tecfsSummarizeCatalogImpl/);
  assert.match(bank2, /cp TFS_SVC_NEXT_CATALOG[\s\S]*jp z,tecfsNextCatalogImpl/);
  assert.match(bank2, /tecfsFormatMetaRecordImpl:[\s\S]*ld b,TFS_META_RECORD_BYTES[\s\S]*djnz tecfsFormatMetaRecordClear[\s\S]*ld a,TFS_FILE_PROJECT/);
  assert.match(bank2, /tecfsPatchMetaRecordImpl:[\s\S]*ld a,\(TFS_META_PATCH_FILE_TYPE\)[\s\S]*ld a,\(TFS_META_PATCH_NAME_REF_HI\)/);
  assert.match(bank2, /tecfsDecodeCatalogImpl:[\s\S]*cp TFS_ENTRY_STATUS_ACTIVE[\s\S]*cp TFS_CATALOG_NAME_BYTES\+1/);
  assert.match(bank2, /tecfsSummarizeCatalogImpl:[\s\S]*call tecfsClearSummary[\s\S]*call tecfsDecodeCatalogImpl/);
  assert.match(bank2, /tecfsNextCatalogImpl:[\s\S]*ld de,TFS_CATALOG_ENTRY_BYTES[\s\S]*add hl,de[\s\S]*ld \(TFS_PARAM_BUFFER_LO\),hl/);
  assert.match(doc, /Formats a TEC-FS locator header into the caller buffer/);
  assert.match(doc, /Validates a caller-buffer locator header and publishes its geometry/);
  assert.match(doc, /Formats a blank TEC-FS v1 metadata record into the caller buffer/);
  assert.match(doc, /Patches mutable fields in a caller-buffer metadata record/);
  assert.match(doc, /Decodes one active 64-byte TM8 catalogue entry/);
  assert.match(doc, /Summarizes one catalogue slot for the shell `dir` path/);
  assert.match(doc, /Advances `TFS_PARAM_BUFFER_LO\/HI` by one 64-byte catalogue slot/);
  assert.match(doc, /does not inspect the slot, find the next\s+active file, cross a sector boundary, or maintain a cursor/);
  assert.match(doc, /not yet a full directory walker/);
});

test('TEC-FS geometry checks are wired into the repository', () => {
  const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));
  const geometryTest = readFileSync(resolve(root, 'tools/tecfs-geometry.test.ts'), 'utf8');

  assert.match(pkg.scripts.test, /tools\/\*\.test\.ts/);
  assert.match(geometryTest, /TFS_VOLUME_MIB/);
  assert.match(geometryTest, /TFS_BLOCK_BYTES/);
  assert.match(geometryTest, /TFS_VOLUME_SECTORS/);
  assert.match(geometryTest, /volumeSectors \* 512/);
  assert.match(geometryTest, /userVolumes \+ 1/);
});

test('TEC-FS bank proof covers unsupported and unknown service selectors', () => {
  const proof = readFileSync(resolve(root, 'proofs/tecfs-bank/tecfs-bank-proof.asm'), 'utf8');
  const runner = readFileSync(resolve(root, 'tools/run-tecfs-bank-proof.ts'), 'utf8');
  const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-banked-service-abi.md'), 'utf8');
  const bank2 = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank2.asm'), 'utf8');

  assert.match(proof, /ld a,TFS_SVC_LOAD_RANGE[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp TFS_ERR_UNSUPPORTED/);
  assert.match(proof, /ld a,TFS_SVC_SAVE_RANGE[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*cp TFS_ERR_UNSUPPORTED/);
  assert.match(proof, /ld a,0x5A[\s\S]*ld \(TFS_PARAM_STATUS\),a[\s\S]*ld a,0xA5[\s\S]*ld \(TFS_PARAM_LAST_ERROR\),a/);
  assert.match(proof, /ld a,0x7F[\s\S]*farCall 0x02,TFS_ENTRY[\s\S]*jp nc,FailUnknownSelector[\s\S]*cp SVC_ERR_UNKNOWN[\s\S]*ld a,\(TFS_PARAM_STATUS\)[\s\S]*cp 0x5A[\s\S]*ld a,\(TFS_PARAM_LAST_ERROR\)[\s\S]*cp 0xA5/);
  assert.match(runner, /TEC-FS status preserved after unknown selector/);
  assert.match(runner, /TEC-FS last error preserved after unknown selector/);
  assert.match(bank2, /cp TFS_SVC_LOAD_RANGE[\s\S]*jp z,tecfsUnsupported[\s\S]*cp TFS_SVC_SAVE_RANGE[\s\S]*jp z,tecfsUnsupported/);
  assert.match(bank2, /ld a,SVC_ERR_UNKNOWN\s+scf\s+ret/);
  assert.match(doc, /unknown-selector path returns `SVC_ERR_UNKNOWN`/);
});

test('TEC-FS direction documents the volume directory contract', () => {
  const direction = readFileSync(resolve(root, 'docs/mon3/tec-fs-direction.md'), 'utf8');
  const bankOps = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank_ops.asmi'), 'utf8');

  assert.match(direction, /^## Volume Directory Contract/m);
  assert.match(direction, /locator sector lives at absolute LBA 1/);
  assert.match(direction, /LBA 0 is the MBR/);
  assert.match(direction, /magic: "TFS1"/);
  assert.match(direction, /volume entry size: 10h/);
  assert.match(direction, /first volume entry/);
  assert.match(direction, /01h user, 02h reserved-work/);
  assert.match(direction, /absolute start sector, little-endian/);
  assert.match(direction, /user volume count: 30/);
  assert.match(direction, /reserved work volume: 30/);
  assert.match(direction, /total selectable volumes: 31/);
  assert.match(direction, /volume sectors: 262,144 = 0x00040000/);
  assert.match(direction, /allocation block size: 4 KiB/);
  assert.match(direction, /allocation blocks per volume: 32,768/);
  assert.match(direction, /absolute_sd_sector = volume_start_sector\[active_volume\] \+ sector_inside_volume/);
  assert.match(direction, /not the live allocation system used by TEC-FS after\s+mount/);
  assert.match(direction, /ordinary file\s+open\/save code should not present it as a normal user drive/);

  for (const [name, value] of [
    ['TFS_LOC_MAGIC_0', '0x54'],
    ['TFS_LOC_MAGIC_1', '0x46'],
    ['TFS_LOC_MAGIC_2', '0x53'],
    ['TFS_LOC_MAGIC_3', '0x31'],
    ['TFS_LOC_VERSION', '0x01'],
    ['TFS_LOC_HEADER_BYTES', '0x20'],
    ['TFS_LOC_ENTRY_BYTES', '0x10'],
    ['TFS_LOC_OFFSET_ENTRIES', '0x20'],
    ['TFS_LOC_ENTRY_START_LBA', '0x03'],
    ['TFS_LOC_ENTRY_SECTORS', '0x07'],
    ['TFS_LOC_ROLE_USER', '0x01'],
    ['TFS_LOC_ROLE_WORK', '0x02'],
    ['TFS_LOC_FLAG_ACTIVE', '0x01'],
  ]) {
    assert.match(bankOps, new RegExp(`^${name}\\s+\\.equ\\s+${value}`, 'm'));
  }
});
