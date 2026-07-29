const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const test = require('node:test');

const root = resolve(__dirname, '..');
const read = (path: string): string => readFileSync(resolve(root, path), 'utf8');

test('ROM editor has a real SD backend and bounded path lookup', () => {
  const bank0 = read('roms/tec1g/tecm8/expansion/bank0.asm');
  const bank2 = read('roms/tec1g/tecm8/expansion/bank2.asm');
  const bank4 = read('roms/tec1g/tecm8/expansion/bank4.asm');
  const bank5 = read('roms/tec1g/tecm8/expansion/bank5.asm');
  const bank8 = read('roms/tec1g/tecm8/expansion/bank8.asm');
  const proof = read('proofs/tecfs-bank/tecfs-mon3-file-proof.asm');
  const packageJson = JSON.parse(read('package.json'));

  assert.match(bank0, /ld hl,TFS_MON3_FILE_DRIVER[\s\S]*ld \(TFS_PARAM_DRIVER_ADDR_LO\),hl/);
  assert.match(bank0, /Tecm8ShellRunCheckEditPath:[\s\S]*SHL_TARGET_KIND_SOURCE_PATH/);
  assert.match(bank2, /tecfsFindPathImpl:[\s\S]*tecfsFindPrefix[\s\S]*tecfsFindCatalog/);
  assert.match(bank2, /tecfsListPathImpl:[\s\S]*tecfsListMaybeAppendEntry/);
  assert.match(bank2, /tecfsCreateSourceImpl:[\s\S]*tecfsCreateFindFreeBlock[\s\S]*tecfsCreateWriteCatalog/);
  assert.match(bank2, /tecfsCreateClearDataBlock[\s\S]*tecfsCreateMarkAllocated[\s\S]*tecfsCreateUpdateSuperblock[\s\S]*tecfsCreateWriteCatalog/);
  assert.match(bank2, /tecfsCreateUpdateSuperblock:[\s\S]*tecfsCreateValidateChecksum[\s\S]*tecfsCreateRecomputeChecksum/);
  assert.match(bank2, /tecfsCommitSourceMetaMon3:[\s\S]*call tecfsReadSectorImpl[\s\S]*call tecfsWriteSectorImpl/);
  assert.match(bank2, /tecfsCreateFileImpl:[\s\S]*TFS_FILE_BINARY[\s\S]*TFS_FILE_ASSET/);
  assert.match(bank2, /tecfsSaveArtifactReal:[\s\S]*tecfsArtifactResolveForSave[\s\S]*tecfsCommitArtifactCatalog/);
  assert.match(bank2, /tecfsLoadArtifactReal:[\s\S]*tecfsArtifactFindPath[\s\S]*tecfsValidateRunnableArtifact/);
  assert.match(bank4, /TFS_SVC_FIND_PATH[\s\S]*TFS_ERR_NOT_FOUND[\s\S]*TFS_SVC_CREATE_SOURCE[\s\S]*TFS_SVC_FIND_PATH/);
  assert.match(bank4, /editorBootImpl:[\s\S]*editorRestoreSession[\s\S]*editorRunLoop/);
  assert.match(bank4, /editorOpenChooser:[\s\S]*TFS_SVC_LIST_PATH[\s\S]*editorRenderFileChooser/);
  assert.match(bank4, /editorCompleteSaveAs:[\s\S]*TFS_SVC_CREATE_SOURCE[\s\S]*editorSave/);
  assert.match(bank4, /editorCompleteRename:[\s\S]*TFS_SVC_RENAME_SOURCE/);
  assert.match(bank4, /editorPrepareSafeSave:[\s\S]*editorBackupCommittedFile[\s\S]*editorWriteSession/);
  assert.match(bank4, /editorRestoreSessionRecovery:[\s\S]*EDT_MODE_RECOVER/);
  assert.match(bank5, /\.org\s+TFS_MON3_FILE_DRIVER[\s\S]*Tecm8Mon3FileDriverEntry:/);
  assert.match(bank5, /\.include "\.\.\/monitor\/pata_fat32\.asm"/);
  assert.match(bank5, /TFS_MON3_FAIL_WRITE_COUNTDOWN[\s\S]*TFS_MON3_FAIL_WRITE_COUNT/);
  assert.match(proof, /TFS_SVC_LIST_PATH[\s\S]*SHL_RUN_COMMAND[\s\S]*SHL_RENDER_RESULT/);
  assert.match(proof, /ld hl,5[\s\S]*TFS_SVC_LIST_PATH[\s\S]*TFS_LIST_FLAG_TRUNCATED/);
  assert.match(proof, /TFS_PARAM_LIST_USED_LO[\s\S]*ld de,1/);
  assert.match(proof, /EDT_SVC_RUN[\s\S]*EDT_STATE_SAVE_COUNT[\s\S]*EDT_SVC_RUN/);
  assert.match(proof, /ProofCreateSource:[\s\S]*ProofWorkspaceEvents[\s\S]*EDT_SVC_BOOT[\s\S]*EDT_WORK_HELP_COUNT[\s\S]*EDT_WORK_OPEN_COUNT[\s\S]*EDT_SVC_OPEN/);
  assert.match(proof, /TFS_MON3_FAIL_WRITE_COUNTDOWN[\s\S]*ProofFailedSaveEvents[\s\S]*ProofRecoveryEvents[\s\S]*EDT_SVC_BOOT[\s\S]*EDT_WORK_RECOVERY_COUNT/);
  assert.match(proof, /TFS_SVC_CREATE_SOURCE[\s\S]*TFS_ERR_EXISTS[\s\S]*TFS_ERR_BAD_PATH/);
  assert.match(proof, /ProofBuildAndRun:[\s\S]*ProofBuildPath[\s\S]*ASM_SVC_ASSEMBLE[\s\S]*ProofRunTarget[\s\S]*RUN_SVC_RUN/);
  assert.match(proof, /ASM_PARAM_DIAG_FILE[\s\S]*ProofLibTarget[\s\S]*EDT_SVC_RUN[\s\S]*ASM_SVC_ASSEMBLE/);
  assert.match(proof, /RUN_SVC_LISTING[\s\S]*RUN_SVC_SYMBOLS[\s\S]*RUN_SVC_DEBUG_START[\s\S]*RUN_SVC_BREAK_SYMBOL[\s\S]*RUN_SVC_DEBUG_STEP[\s\S]*RUN_SVC_DEBUG_CONTINUE/);
  assert.match(proof, /ProofRebuildAndRerun:[\s\S]*ProofRebuildEvents[\s\S]*ASM_SVC_ASSEMBLE[\s\S]*RUN_SVC_RUN/);
  assert.match(bank8, /debugFormatSourceMap:[\s\S]*debugFormatSymbols:/);
  assert.match(bank8, /debugPrepareSingleStep:[\s\S]*debugSequentialFallback:[\s\S]*debugBaseLengthTable:/);
  assert.match(bank8, /debugTrap:[\s\S]*debugProgramFinished:[\s\S]*debugPublishStopped:/);
  assert.equal(
    packageJson.scripts['proof:tecfs-mon3-file'],
    'node --experimental-strip-types tools/run-tecfs-mon3-file-proof.ts',
  );
  assert.match(packageJson.scripts['debug80:tecmate-workspace-image'], /--prepare-only/);
  assert.match(packageJson.scripts.check, /proof:tecfs-mon3-file/);
});
