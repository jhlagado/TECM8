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

test('banked service ABI doc covers fixed monitor bank services', () => {
  for (const name of [
    'TECM8_BIOS_SYS_GET',
    'TECM8_BIOS_SYS_SET',
    'TECM8_BIOS_BANK_SELECT',
    'TECM8_BIOS_BANK_CALL',
    'TECM8_BIOS_FAR_JUMP',
    'TECM8_BIOS_SERVICE_BRIDGE',
  ]) {
    assertDocRow(name);
  }
  assert.match(doc, /## Planned Fixed-ROM Service Bridge/);
  assert.match(doc, /reserves `RST 10h` selector `C=60h`/);
  assert.match(doc, /`A` carries the TecMate service ID and is not an\s+argument to the target service/);
  assert.match(doc, /build the same per-call\s+stack-word request used by `callService`/);
  assert.match(doc, /enter physical bank 0 at\s+`TECM8_SERVICE_CALL` through `BiosBankCall`/);
  assert.match(doc, /Unknown service IDs return\s+`TECM8_SERVICE_ERR_UNKNOWN` with carry set/);
});

test('banked service ABI doc covers bank 0 service registry entries', () => {
  for (const name of [
    'TECM8_SERVICE_VDU_INIT_BANK',
    'TECM8_SERVICE_VDU_INIT_ADDR',
    'TECM8_SERVICE_TECFS_MOUNT_BANK',
    'TECM8_SERVICE_TECFS_MOUNT_ADDR',
    'TECM8_SERVICE_RTC_TOOL_BANK',
    'TECM8_SERVICE_RTC_TOOL_ADDR',
    'TECM8_SERVICE_GLCD_ENTRY_BANK',
    'TECM8_SERVICE_GLCD_ENTRY_ADDR',
    'TECM8_SERVICE_SHELL_ENTRY_BANK',
    'TECM8_SERVICE_SHELL_ENTRY_ADDR',
  ]) {
    assertDocRow(name);
  }
  assert.match(ops, /op callService\(service imm8\)/);
  assert.doesNotMatch(ops, /TECM8_SERVICE_REQUEST/);
  assert.match(doc, /callService TECM8_SERVICE_VDU_INIT/);
  assert.match(doc, /per-call stack word/);
});

test('banked service ABI doc covers bank 1 VDU/TMS slots and parameters', () => {
  for (const name of [
    'TECM8_VDU_ENTRY',
    'TECM8_VDU_SERVICE_CALL',
    'TECM8_VDU_SERVICE_TABLE',
    'TECM8_VDU_SVC_INIT',
    'TECM8_VDU_SVC_CLEAR',
    'TECM8_VDU_SVC_SET_CURSOR',
    'TECM8_VDU_SVC_PUT_CHAR',
    'TECM8_VDU_SVC_PUT_STRING',
    'TECM8_VDU_SVC_NEWLINE',
    'TECM8_TMS_SVC_INIT',
    'TECM8_TMS_SVC_SET_REGISTER',
    'TECM8_TMS_SVC_WRITE_VRAM',
    'TECM8_TMS_DATA_PORT',
    'TECM8_TMS_CONTROL_PORT',
    'TECM8_TMS_PARAM_BASE',
    'TECM8_TMS_PARAM_VALUE',
    'TECM8_TMS_PARAM_REGISTER',
    'TECM8_TMS_PARAM_ADDR_LO',
    'TECM8_TMS_PARAM_ADDR_HI',
    'TECM8_TMS_PARAM_CURSOR_LO',
    'TECM8_TMS_PARAM_CURSOR_HI',
    'TECM8_TMS_PARAM_STRING_LO',
    'TECM8_TMS_PARAM_STRING_HI',
    'TECM8_VDU_TEXT_ROW_BYTES',
  ]) {
    assertDocRow(name);
  }
  assert.match(doc, /Minimal VDU text-console contract/);
  assert.match(doc, /one public dispatcher, not one fixed callable address per VDU/);
  assert.match(doc, /implementation labels are not ABI/);
  assert.match(doc, /writes `TECM8_TMS_PARAM_VALUE` at the current cursor/);
});

test('banked service ABI doc covers bank 0 shell entry slots and parameters', () => {
  for (const name of [
    'TECM8_SHELL_ENTRY',
    'TECM8_SHELL_PARAM_BASE',
    'TECM8_SHELL_PARAM_STATUS',
    'TECM8_SHELL_PARAM_LAST_ERROR',
    'TECM8_SHELL_PARAM_BANK',
    'TECM8_SHELL_PARAM_VERSION',
    'TECM8_SHELL_PARAM_FEATURES',
    'TECM8_SHELL_SPLASH_BUFFER',
    'TECM8_SHELL_STATUS_OK',
    'TECM8_SHELL_FEATURE_ENTRY',
    'TECM8_SHELL_FEATURE_SPLASH',
  ]) {
    assertDocRow(name);
  }
});

test('banked service ABI doc covers bank 2 TEC-FS slots and parameters', () => {
  for (const name of [
    'TECM8_TECFS_ENTRY',
    'TECM8_TECFS_MOUNT',
    'TECM8_TECFS_SELECT_VOLUME',
    'TECM8_TECFS_READ',
    'TECM8_TECFS_WRITE',
    'TECM8_TECFS_LOAD_RANGE',
    'TECM8_TECFS_SAVE_RANGE',
    'TECM8_TECFS_MAP_BLOCK',
    'TECM8_TECFS_TRANSLATE_SECTOR',
    'TECFS_PARAM_BASE',
    'TECFS_PARAM_ACTIVE_VOLUME',
    'TECFS_PARAM_REQUEST_VOLUME',
    'TECFS_PARAM_STATUS',
    'TECFS_PARAM_LAST_ERROR',
    'TECFS_PARAM_VOLUME_MIB',
    'TECFS_PARAM_BLOCK_BYTES_LO',
    'TECFS_PARAM_BLOCK_BYTES_HI',
    'TECFS_PARAM_VOLUME_BLOCKS_LO',
    'TECFS_PARAM_VOLUME_BLOCKS_HI',
    'TECFS_PARAM_USER_VOLUMES',
    'TECFS_PARAM_SPARE_VOLUME',
    'TECFS_PARAM_TOTAL_VOLUMES',
    'TECFS_PARAM_BLOCK_INDEX_LO',
    'TECFS_PARAM_BLOCK_INDEX_HI',
    'TECFS_PARAM_SECTOR_0',
    'TECFS_PARAM_SECTOR_1',
    'TECFS_PARAM_SECTOR_2',
    'TECFS_PARAM_SECTOR_3',
    'TECFS_PARAM_BUFFER_LO',
    'TECFS_PARAM_BUFFER_HI',
    'TECFS_PARAM_DRIVER_OP',
    'TECFS_PARAM_LOCATOR_SECTOR_0',
    'TECFS_PARAM_LOCATOR_SECTOR_1',
    'TECFS_PARAM_LOCATOR_SECTOR_2',
    'TECFS_PARAM_LOCATOR_SECTOR_3',
    'TECFS_PARAM_VOLUME_SECTORS_0',
    'TECFS_PARAM_VOLUME_SECTORS_1',
    'TECFS_PARAM_VOLUME_SECTORS_2',
    'TECFS_PARAM_VOLUME_SECTORS_3',
    'TECFS_DRIVER_OP_READ',
    'TECFS_DRIVER_OP_WRITE',
    'TECFS_LOCATOR_LBA_0',
    'TECFS_LOCATOR_LBA_1',
    'TECFS_LOCATOR_LBA_2',
    'TECFS_LOCATOR_LBA_3',
    'TECFS_VOLUME_SECTORS_0',
    'TECFS_VOLUME_SECTORS_1',
    'TECFS_VOLUME_SECTORS_2',
    'TECFS_VOLUME_SECTORS_3',
    'TECFS_IMAGE_BASE_LBA_0',
    'TECFS_IMAGE_BASE_LBA_1',
    'TECFS_IMAGE_BASE_LBA_2',
    'TECFS_IMAGE_BASE_LBA_3',
    'TECFS_LOCATOR_MAGIC_0',
    'TECFS_LOCATOR_MAGIC_1',
    'TECFS_LOCATOR_MAGIC_2',
    'TECFS_LOCATOR_MAGIC_3',
    'TECFS_LOCATOR_VERSION',
    'TECFS_LOCATOR_HEADER_BYTES',
    'TECFS_LOCATOR_ENTRY_BYTES',
    'TECFS_LOCATOR_OFFSET_MAGIC',
    'TECFS_LOCATOR_OFFSET_VERSION',
    'TECFS_LOCATOR_OFFSET_ENTRY_SIZE',
    'TECFS_LOCATOR_OFFSET_TOTAL_VOLUMES',
    'TECFS_LOCATOR_OFFSET_USER_VOLUMES',
    'TECFS_LOCATOR_OFFSET_SPARE_VOLUME',
    'TECFS_LOCATOR_OFFSET_VOLUME_SECTORS',
    'TECFS_LOCATOR_OFFSET_GENERATION',
    'TECFS_LOCATOR_OFFSET_CHECKSUM',
    'TECFS_LOCATOR_OFFSET_ENTRIES',
    'TECFS_LOCATOR_ENTRY_VOLUME',
    'TECFS_LOCATOR_ENTRY_ROLE',
    'TECFS_LOCATOR_ENTRY_FLAGS',
    'TECFS_LOCATOR_ENTRY_START_LBA',
    'TECFS_LOCATOR_ENTRY_SECTORS',
    'TECFS_LOCATOR_ENTRY_GENERATION',
    'TECFS_LOCATOR_ENTRY_CHECKSUM',
    'TECFS_LOCATOR_ROLE_USER',
    'TECFS_LOCATOR_ROLE_WORK',
    'TECFS_LOCATOR_FLAG_ACTIVE',
    'TECFS_STATUS_OK',
    'TECFS_ERR_BAD_VOLUME',
    'TECFS_ERR_BAD_BLOCK',
    'TECFS_ERR_BAD_SECTOR',
    'TECFS_ERR_BAD_BUFFER',
    'TECFS_ERR_NO_DRIVER',
    'TECFS_ERR_UNSUPPORTED',
  ]) {
    assertDocRow(name);
  }
  assert.match(doc, /sector I\/O contract/);
  assert.match(doc, /sector driver hook/);
  assert.match(doc, /128 MiB/);
  assert.match(doc, /32768/);
  assert.match(doc, /30 user volumes/);
  assert.match(doc, /TEC-FS locator sector/);
  assert.match(doc, /absolute LBA 1/);
  assert.match(doc, /magic is `TFS1`/);
  assert.match(doc, /16-byte volume records/);
  assert.match(doc, /262,144/);
  assert.match(doc, /logical-to-card translation/);
  assert.match(doc, /image-base LBA/);
});

test('banked service ABI doc covers bank 3 RTC slots and parameters', () => {
  for (const name of [
    'TECM8_RTC_ENTRY',
    'TECM8_RTC_TOOL_ENTRY',
    'TECM8_RTC_SETUP_UI',
    'TECM8_RTC_PRAM_VIEWER',
    'TECM8_RTC_PARAM_BASE',
    'TECM8_RTC_PARAM_STATUS',
    'TECM8_RTC_PARAM_LAST_ERROR',
    'TECM8_RTC_PARAM_BANK',
    'TECM8_RTC_PARAM_VERSION',
    'TECM8_RTC_PARAM_FEATURES',
    'TECM8_RTC_STATUS_OK',
    'TECM8_RTC_FEATURE_SERVICE',
    'TECM8_RTC_ERR_UNSUPPORTED',
  ]) {
    assertDocRow(name);
  }
});

test('banked service ABI doc covers bank 4 GLCD boundary slots and parameters', () => {
  for (const name of [
    'TECM8_GLCD_ENTRY',
    'TECM8_GLCD_INIT',
    'TECM8_GLCD_CLEAR',
    'TECM8_GLCD_PLOT',
    'TECM8_GLCD_PARAM_BASE',
    'TECM8_GLCD_PARAM_STATUS',
    'TECM8_GLCD_PARAM_LAST_ERROR',
    'TECM8_GLCD_PARAM_BANK',
    'TECM8_GLCD_PARAM_VERSION',
    'TECM8_GLCD_PARAM_FEATURES',
    'TECM8_GLCD_STATUS_OK',
    'TECM8_GLCD_FEATURE_BOUNDARY',
    'TECM8_GLCD_ERR_UNSUPPORTED',
  ]) {
    assertDocRow(name);
  }
});

test('banked service ABI doc covers proof hooks and proof scripts', () => {
  for (const name of [
    'TECM8_ABI_TRACE_BASE',
    'TECM8_ABI_TRACE_0',
    'TECM8_ABI_TRACE_1',
    'TECM8_ABI_TRACE_2',
    'TECM8_ABI_TRACE_3',
    'TECM8_ABI_TRACE_4',
    'TECM8_ABI_TRACE_5',
    'TECM8_ABI_TRACE_6',
    'TECM8_ABI_TRACE_7',
    'TECM8_ABI_TRACE_8',
    'TECM8_ABI_TRACE_9',
    'TECM8_ABI_FARJUMP_LANDED',
    'TECM8_ABI_BANK1_NESTED',
    'TECM8_ABI_BANK2_NESTED',
    'TECM8_ABI_BANK3_FARJUMP',
  ]) {
    assertDocRow(name);
  }
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
