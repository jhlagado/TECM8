const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = resolve(__dirname, '..');
const doc = readFileSync(resolve(root, 'docs/mon3/tecmate-banked-service-abi.md'), 'utf8');
const ops = readFileSync(resolve(root, 'roms/tec1g/tecm8/expansion/bank_ops.asmi'), 'utf8');
const pkg = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8'));

function equateExpression(name: string): string {
  const match = ops.match(new RegExp(`^${name}\\s+\\.equ\\s+([^\\n;]+)`, 'm'));
  assert.ok(match, `missing equate ${name}`);
  return match[1].trim();
}

function parseNumber(token: string): number {
  const trimmed = token.trim();
  if (/^0x[0-9a-f]+$/i.test(trimmed)) {
    return Number.parseInt(trimmed.slice(2), 16);
  }
  if (/^[0-9a-f]+h$/i.test(trimmed)) {
    return Number.parseInt(trimmed.slice(0, -1), 16);
  }
  if (/^[0-9]+$/.test(trimmed)) {
    return Number.parseInt(trimmed, 10);
  }
  return equateValue(trimmed);
}

function equateValue(name: string): number {
  const expression = equateExpression(name);
  return expression
    .split('+')
    .map((part) => parseNumber(part))
    .reduce((sum, value) => sum + value, 0);
}

function hexForDoc(value: number): string {
  const width = value <= 0xff ? 2 : 4;
  return `${value.toString(16).toUpperCase().padStart(width, '0')}h`;
}

function assertDocRow(name: string): void {
  const expected = hexForDoc(equateValue(name));
  const row = doc.split('\n').find((line: string) => line.includes(`\`${name}\``));
  assert.ok(row, `doc should mention ${name}`);
  assert.match(row, new RegExp(`\\|\\s*\\\`${name}\\\`\\s*\\|\\s*\\\`?${expected}\\\`?\\s*\\|`, 'i'));
}

function assertDocMentions(name: string): void {
  assert.match(doc, new RegExp(`\\\`${name}\\\``));
}

test('banked service ABI doc covers fixed monitor bank services', () => {
  for (const name of [
    'MON_SYS_GET',
    'MON_SYS_SET',
    'MON_BANK_SELECT',
    'MON_BANK_CALL',
    'MON_FAR_JUMP',
    'SVC_BASE',
  ]) {
    assertDocRow(name);
  }
  assert.match(doc, /## Fixed-ROM Expansion Services/);
  assert.match(doc, /`C < SVC_BASE` as a\s+normal fixed API-table call and `C >= SVC_BASE` as an expansion service request/);
  assert.match(doc, /`C` carries the TecMate service ID directly/);
  assert.match(doc, /validates the\s+installed service vector/);
  assert.match(doc, /enters that bank\/address through `BiosBankCall`/);
  assert.match(doc, /Unknown service IDs are returned by the\s+installed dispatcher as `SVC_ERR_UNKNOWN` with carry set/);
  assert.match(doc, /If no valid service\s+vector is installed, fixed ROM returns `A=FFh` with carry set/);
});

test('banked service ABI doc covers bank 0 service registry entries', () => {
  for (const name of [
    'VDU_BANK',
    'VDU_ADDR',
    'TFS_BANK',
    'TFS_ADDR',
    'RTC_BANK',
    'RTC_ADDR',
    'GLC_BANK',
    'GLC_ADDR',
    'INP_READ',
    'INP_BANK',
    'INP_ADDR',
    'SHL_BANK',
  ]) {
    assertDocRow(name);
  }
  assert.match(ops, /op callService\(service imm8\)/);
  assert.match(ops, /ld c,service\s+rst 10H/);
  assert.doesNotMatch(ops, /TECM8_BIOS_SERVICE_BRIDGE/);
  assert.doesNotMatch(ops, /ld hl,TECM8_SERVICE_CALL\s+ld c,MON_BANK_CALL\s+rst 10H/);
  assert.doesNotMatch(ops, /TECM8_SERVICE_REQUEST/);
  assert.match(doc, /callService VDU_INIT/);
  assert.match(doc, /requested service ID into `C`/);
  assert.match(doc, /dispatcher and registry labels are private implementation details/);
  assert.doesNotMatch(doc, /`TECM8_SERVICE_CALL`/);
  assert.doesNotMatch(doc, /`TECM8_SERVICE_REGISTRY`/);
});

test('banked service ABI doc covers bank 1 VDU/TMS slots and parameters', () => {
  for (const name of [
    'VDU_ENTRY',
    'VDU_CALL',
    'VDU_SVC_INIT',
    'VDU_SVC_CLEAR',
    'VDU_SVC_SET_CURSOR',
    'VDU_SVC_PUT_CHAR',
    'VDU_SVC_PUT_STRING',
    'VDU_SVC_NEWLINE',
    'VDU_SVC_SET_ROWCOL',
    'VDU_SVC_SCROLL_UP',
    'VDU_SVC_STATUS_LINE',
    'TMS_SVC_INIT',
    'TMS_SVC_SET_REGISTER',
    'TMS_SVC_WRITE_VRAM',
    'TMS_SVC_FILL_VRAM',
    'TMS_SVC_READ_VRAM',
    'TMS_DATA_PORT',
    'TMS_CONTROL_PORT',
    'TMS_PARAM_BASE',
    'TMS_PARAM_VALUE',
    'TMS_PARAM_REGISTER',
    'TMS_PARAM_ADDR_LO',
    'TMS_PARAM_ADDR_HI',
    'TMS_PARAM_CURSOR_LO',
    'TMS_PARAM_CURSOR_HI',
    'TMS_PARAM_STRING_LO',
    'TMS_PARAM_STRING_HI',
    'TMS_PARAM_COUNT_LO',
    'TMS_PARAM_COUNT_HI',
    'TMS_PARAM_ROW',
    'TMS_PARAM_COL',
    'VDU_ROW_BYTES',
    'VDU_SCREEN_BYTES',
    'VDU_BLANK_CHAR',
    'VDU_ROWS',
    'VDU_SCROLL_BYTES',
    'VDU_LAST_ROW_ADDR',
  ]) {
    assertDocRow(name);
  }
  assert.match(doc, /Minimal VDU text-console contract/);
  assert.match(doc, /one public dispatcher, not one fixed callable address per VDU/);
  assert.match(doc, /implementation labels are not ABI/);
  assert.match(doc, /`VDU_TABLE` \| private label/);
  assert.match(doc, /`VDU_SVC_CLEAR` fills VRAM `0000h\.\.02FFh` with `VDU_BLANK_CHAR`/);
  assert.match(doc, /`VDU_SVC_SET_ROWCOL` computes `row \* 32 \+ \(col & 1Fh\)`/);
  assert.match(doc, /`VDU_SVC_SCROLL_UP` copies rows 1-23 to rows 0-22/);
  assert.match(doc, /`VDU_SVC_STATUS_LINE` blanks the final row/);
  assert.match(doc, /restores the\s+cursor that was active before the call/);
  assert.match(doc, /`TMS_SVC_FILL_VRAM` writes `TMS_PARAM_VALUE` to `TMS_PARAM_COUNT_LO\/HI`/);
  assert.match(doc, /`TMS_SVC_READ_VRAM` reads one byte/);
  assert.match(doc, /writes `TMS_PARAM_VALUE` at the current cursor/);
});

test('banked service ABI doc covers bank 0 shell entry slots and parameters', () => {
  assertDocMentions('SHL_ENTRY');
  assertDocMentions('SHL_RUN_COMMAND');
  for (const name of [
    'SHL_PARAM_BASE',
    'SHL_PARAM_STATUS',
    'SHL_PARAM_LAST_ERROR',
    'SHL_PARAM_BANK',
    'SHL_PARAM_VERSION',
    'SHL_PARAM_FEATURES',
    'SHL_PARAM_COMMAND_ACTION',
    'SHL_PARAM_COMMAND_LENGTH',
    'SHL_PARAM_COMMAND_TARGET_LO',
    'SHL_PARAM_COMMAND_TARGET_HI',
    'SHL_PARAM_COMMAND_RESULT_LO',
    'SHL_PARAM_COMMAND_RESULT_HI',
    'SHL_TARGET_DESC',
    'SHL_TARGET_ACTION',
    'SHL_TARGET_KIND',
    'SHL_TARGET_PATH_LO',
    'SHL_TARGET_PATH_HI',
    'SHL_TARGET_FLAGS',
    'SHL_STATUS_BUFFER',
    'SHL_STATUS_CAPACITY',
    'SHL_SPLASH_BUFFER',
    'SHL_COMMAND_BUFFER',
    'SHL_COMMAND_CAPACITY',
    'SHL_STATUS_OK',
    'SHL_STATUS_UNKNOWN_COMMAND',
    'SHL_FEATURE_ENTRY',
    'SHL_FEATURE_SPLASH',
    'SHL_FEATURE_COMMAND_LOOP',
    'SHL_ACTION_NONE',
    'SHL_ACTION_EDIT',
    'SHL_ACTION_ASM',
    'SHL_ACTION_RUN',
    'SHL_TARGET_KIND_NONE',
    'SHL_TARGET_KIND_PROJECT_MAIN',
    'SHL_TARGET_KIND_PROJECT_OUTPUT',
    'SHL_TARGET_FLAG_DEFAULT',
    'SHL_RESULT_NONE',
    'SHL_RESULT_OK',
    'SHL_RESULT_BUILD_ERROR',
    'SHL_RESULT_FILE_ERROR',
    'SHL_RESULT_UNSUPPORTED',
  ]) {
    assertDocRow(name);
  }
  assert.match(doc, /private `Tecm8ShellEntry` label/);
  assert.match(doc, /writes a\s+short status string through the VDU status-line service/);
  assert.match(doc, /do not\s+call that label directly/);
  assert.match(doc, /private `Tecm8ShellRunCommand` label/);
  assert.match(doc, /`SHL_RUN_COMMAND` reads a zero-terminated command line/);
  assert.match(doc, /classifies the\s+first shell verbs: `edit`, `asm`, and `run`/);
  assert.match(doc, /writes `SHL_PARAM_COMMAND_TARGET_LO\/HI` to point\s+at `SHL_TARGET_DESC`/);
  assert.match(doc, /publishes\s+`SHL_RESULT_UNSUPPORTED` for `asm` until the assembler is linked/);
  assert.match(doc, /`edit` and `asm` use `SHL_TARGET_KIND_PROJECT_MAIN`/);
  assert.match(doc, /`run` uses\s+`SHL_TARGET_KIND_PROJECT_OUTPUT`/);
  assert.match(doc, /low\s+result byte should use `SHL_RESULT_\*`/);
  assert.match(doc, /assembler diagnostic line or zero when no detail applies/);
});

test('banked service ABI doc covers bank 2 TEC-FS slots and parameters', () => {
  for (const name of [
    'TFS_ENTRY',
    'TFS_ENTRY_MOUNT',
    'TFS_SELECT_VOLUME',
    'TFS_READ',
    'TFS_WRITE',
    'TFS_LOAD_RANGE',
    'TFS_SAVE_RANGE',
    'TFS_MAP_BLOCK',
    'TFS_TRANSLATE_SECTOR',
    'TFS_FORMAT_LOCATOR',
    'TFS_READ_LOCATOR',
    'TFS_FORMAT_META_RECORD',
    'TFS_SVC_MOUNT',
    'TFS_SVC_SELECT_VOLUME',
    'TFS_SVC_READ',
    'TFS_SVC_WRITE',
    'TFS_SVC_LOAD_RANGE',
    'TFS_SVC_SAVE_RANGE',
    'TFS_SVC_MAP_BLOCK',
    'TFS_SVC_TRANSLATE_SECTOR',
    'TFS_SVC_FORMAT_LOCATOR',
    'TFS_SVC_READ_LOCATOR',
    'TFS_SVC_FORMAT_META_RECORD',
    'TFS_PARAM_BASE',
    'TFS_PARAM_ACTIVE_VOLUME',
    'TFS_PARAM_REQUEST_VOLUME',
    'TFS_PARAM_STATUS',
    'TFS_PARAM_LAST_ERROR',
    'TFS_PARAM_VOLUME_MIB',
    'TFS_PARAM_BLOCK_BYTES_LO',
    'TFS_PARAM_BLOCK_BYTES_HI',
    'TFS_PARAM_VOLUME_BLOCKS_LO',
    'TFS_PARAM_VOLUME_BLOCKS_HI',
    'TFS_PARAM_USER_VOLUMES',
    'TFS_PARAM_SPARE_VOLUME',
    'TFS_PARAM_TOTAL_VOLUMES',
    'TFS_PARAM_BLOCK_INDEX_LO',
    'TFS_PARAM_BLOCK_INDEX_HI',
    'TFS_PARAM_SECTOR_0',
    'TFS_PARAM_SECTOR_1',
    'TFS_PARAM_SECTOR_2',
    'TFS_PARAM_SECTOR_3',
    'TFS_PARAM_BUFFER_LO',
    'TFS_PARAM_BUFFER_HI',
    'TFS_PARAM_DRIVER_OP',
    'TFS_PARAM_LOCATOR_SECTOR_0',
    'TFS_PARAM_LOCATOR_SECTOR_1',
    'TFS_PARAM_LOCATOR_SECTOR_2',
    'TFS_PARAM_LOCATOR_SECTOR_3',
    'TFS_PARAM_VOLUME_SECTORS_0',
    'TFS_PARAM_VOLUME_SECTORS_1',
    'TFS_PARAM_VOLUME_SECTORS_2',
    'TFS_PARAM_VOLUME_SECTORS_3',
    'TFS_PARAM_DRIVER_BANK',
    'TFS_PARAM_DRIVER_ADDR_LO',
    'TFS_PARAM_DRIVER_ADDR_HI',
    'TFS_DRIVER_OP_READ',
    'TFS_DRIVER_OP_WRITE',
    'TFS_LOC_LBA_0',
    'TFS_LOC_LBA_1',
    'TFS_LOC_LBA_2',
    'TFS_LOC_LBA_3',
    'TFS_VOLUME_SECTORS_0',
    'TFS_VOLUME_SECTORS_1',
    'TFS_VOLUME_SECTORS_2',
    'TFS_VOLUME_SECTORS_3',
    'TFS_IMAGE_BASE_LBA_0',
    'TFS_IMAGE_BASE_LBA_1',
    'TFS_IMAGE_BASE_LBA_2',
    'TFS_IMAGE_BASE_LBA_3',
    'TFS_LOC_MAGIC_0',
    'TFS_LOC_MAGIC_1',
    'TFS_LOC_MAGIC_2',
    'TFS_LOC_MAGIC_3',
    'TFS_LOC_VERSION',
    'TFS_LOC_HEADER_BYTES',
    'TFS_LOC_ENTRY_BYTES',
    'TFS_LOC_OFFSET_MAGIC',
    'TFS_LOC_OFFSET_VERSION',
    'TFS_LOC_OFFSET_ENTRY_SIZE',
    'TFS_LOC_OFFSET_TOTAL_VOLUMES',
    'TFS_LOC_OFFSET_USER_VOLUMES',
    'TFS_LOC_OFFSET_SPARE_VOLUME',
    'TFS_LOC_OFFSET_VOLUME_SECTORS',
    'TFS_LOC_OFFSET_GENERATION',
    'TFS_LOC_OFFSET_CHECKSUM',
    'TFS_LOC_OFFSET_ENTRIES',
    'TFS_LOC_ENTRY_VOLUME',
    'TFS_LOC_ENTRY_ROLE',
    'TFS_LOC_ENTRY_FLAGS',
    'TFS_LOC_ENTRY_START_LBA',
    'TFS_LOC_ENTRY_SECTORS',
    'TFS_LOC_ENTRY_GENERATION',
    'TFS_LOC_ENTRY_CHECKSUM',
    'TFS_LOC_ROLE_USER',
    'TFS_LOC_ROLE_WORK',
    'TFS_LOC_FLAG_ACTIVE',
    'TFS_META_MAGIC_0',
    'TFS_META_MAGIC_1',
    'TFS_META_MAGIC_2',
    'TFS_META_MAGIC_3',
    'TFS_META_VERSION',
    'TFS_META_RECORD_BYTES',
    'TFS_META_OFFSET_MAGIC',
    'TFS_META_OFFSET_VERSION',
    'TFS_META_OFFSET_RECORD_BYTES',
    'TFS_META_OFFSET_FILE_TYPE',
    'TFS_META_OFFSET_FLAGS',
    'TFS_META_OFFSET_LOAD_ADDR',
    'TFS_META_OFFSET_END_ADDR',
    'TFS_META_OFFSET_RUN_ADDR',
    'TFS_META_OFFSET_REQUIRED_HW',
    'TFS_META_OFFSET_NAME_REF',
    'TFS_FILE_PROJECT',
    'TFS_FILE_SOURCE',
    'TFS_FILE_BINARY',
    'TFS_FILE_GAME',
    'TFS_FILE_BASIC',
    'TFS_FILE_ASSET',
    'TFS_META_FLAG_EXECUTABLE',
    'TFS_META_FLAG_EXP_RAM',
    'TFS_META_HW_TMS9918',
    'TFS_META_HW_GLCD',
    'TFS_META_HW_JOYSTICK',
    'TFS_STATUS_OK',
    'TFS_ERR_BAD_VOLUME',
    'TFS_ERR_BAD_BLOCK',
    'TFS_ERR_BAD_SECTOR',
    'TFS_ERR_BAD_BUFFER',
    'TFS_ERR_BAD_LOCATOR',
    'TFS_ERR_NO_DRIVER',
    'TFS_ERR_UNSUPPORTED',
  ]) {
    assertDocRow(name);
  }
  assert.match(doc, /sector I\/O contract/);
  assert.match(doc, /installed sector-driver vector/);
  assert.match(doc, /driver receives `A=TFS_DRIVER_OP_READ` or `A=TFS_DRIVER_OP_WRITE`/);
  assert.match(doc, /128 MiB/);
  assert.match(doc, /32768/);
  assert.match(doc, /30 user volumes/);
  assert.match(doc, /TEC-FS locator sector/);
  assert.match(doc, /`TFS_FORMAT_LOCATOR` writes the current locator header fields/);
  assert.match(doc, /`TFS_READ_LOCATOR` validates the magic\/version/);
  assert.match(doc, /absolute LBA 1/);
  assert.match(doc, /magic is `TFS1`/);
  assert.match(doc, /16-byte volume records/);
  assert.match(doc, /262,144/);
  assert.match(doc, /logical-to-card translation/);
  assert.match(doc, /image-base LBA/);
  assert.match(doc, /`TFS_FORMAT_META_RECORD` writes a blank 32-byte `TFM1` metadata record/);
  assert.match(doc, /file type,\s+flags, load\/end\/run addresses, required hardware, and a long-name reference/);
  assert.match(doc, /default formatted record is `TFS_FILE_PROJECT`/);
});

test('banked service ABI doc covers bank 3 RTC slots and parameters', () => {
  for (const name of [
    'RTC_ENTRY',
    'RTC_TOOL_ADDR',
    'RTC_SETUP_UI',
    'RTC_PRAM_VIEWER',
    'RTC_PARAM_BASE',
    'RTC_PARAM_STATUS',
    'RTC_PARAM_LAST_ERROR',
    'RTC_PARAM_BANK',
    'RTC_PARAM_VERSION',
    'RTC_PARAM_FEATURES',
    'RTC_STATUS_OK',
    'RTC_FEATURE_SERVICE',
    'RTC_ERR_UNSUPPORTED',
  ]) {
    assertDocRow(name);
  }
});

test('banked service ABI doc covers bank 4 GLCD boundary slots and parameters', () => {
  for (const name of [
    'GLC_ENTRY_ADDR',
    'GLC_INIT',
    'GLC_CLEAR',
    'GLC_PLOT',
    'GLC_PARAM_BASE',
    'GLC_PARAM_STATUS',
    'GLC_PARAM_LAST_ERROR',
    'GLC_PARAM_BANK',
    'GLC_PARAM_VERSION',
    'GLC_PARAM_FEATURES',
    'GLC_STATUS_OK',
    'GLC_FEATURE_BOUNDARY',
    'GLC_ERR_UNSUPPORTED',
  ]) {
    assertDocRow(name);
  }
});

test('banked service ABI doc covers bank 5 TEC-FS monitor-sector bridge', () => {
  assert.match(doc, /## Bank 5: TEC-FS Monitor-Sector Bridge/);
  assert.match(doc, /sector-driver bridge boundary/);
  assert.match(doc, /bridge\s+`TFS_DRIVER_OP_READ` and `TFS_DRIVER_OP_WRITE` to the selected low-level SD/);
  assert.match(doc, /TFS_PARAM_DRIVER_BANK/);
  assert.match(doc, /returns `A=85h` with carry clear/);
  assert.match(doc, /writes `TFS_BRIDGE_READ_MARKER` into the\s+caller buffer for read requests/);
});

test('banked service ABI doc covers bank 6 input snapshot boundary', () => {
  for (const name of [
    'INP_ENTRY',
    'INP_SVC_READ',
    'INP_PARAM_BASE',
    'INP_PARAM_STATUS',
    'INP_PARAM_LAST_ERROR',
    'INP_PARAM_BANK',
    'INP_PARAM_VERSION',
    'INP_PARAM_KEYS_LO',
    'INP_PARAM_KEYS_HI',
    'INP_PARAM_JOYSTICK',
    'INP_PARAM_MODIFIERS',
    'INP_STATUS_OK',
    'INP_ERR_UNKNOWN',
    'INP_JOY_UP',
    'INP_JOY_DOWN',
    'INP_JOY_LEFT',
    'INP_JOY_RIGHT',
    'INP_JOY_FIRE_1',
    'INP_JOY_FIRE_2',
  ]) {
    assertDocRow(name);
  }
  assert.match(doc, /## Bank 6: Input Snapshot Boundary/);
  assert.match(doc, /matrix-keyboard and joystick-facing service/);
  assert.match(doc, /returns a no-input snapshot/);
  assert.match(doc, /shell, editor, assembler, debugger, and game support code/);
});

test('banked service ABI doc covers proof hooks and proof scripts', () => {
  for (const name of [
    'ABI_TRACE_BASE',
    'ABI_TRACE_0',
    'ABI_TRACE_1',
    'ABI_TRACE_2',
    'ABI_TRACE_3',
    'ABI_TRACE_4',
    'ABI_TRACE_5',
    'ABI_TRACE_6',
    'ABI_TRACE_7',
    'ABI_TRACE_8',
    'ABI_TRACE_9',
    'ABI_FARJUMP_LANDED',
    'ABI_PROBE_REQUEST',
    'ABI_PROBE_NESTED',
    'ABI_PROBE_PRESERVE',
    'ABI_PROBE_FARJUMP',
    'ABI_PROBE_RETURNING_FARJUMP',
  ]) {
    assertDocRow(name);
  }
  assert.match(doc, /does not publish fixed expansion-ROM target\s+addresses/);
  for (const script of [
    'proof:bank-abi',
    'proof:tms9918-bank',
    'proof:tecfs-bank',
    'proof:rtc-bank',
  ]) {
    assert.ok(pkg.scripts[script], `missing npm script ${script}`);
    assert.match(doc, new RegExp(`npm run ${script}`));
  }
});
