const { existsSync, readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { pathToFileURL } = require('node:url');

const DEFAULT_DEBUG80_ROOT = resolve(__dirname, '../..', 'debug80');

type Debug80RuntimeModules = {
  createTec1gRuntime: Function;
  createTec1gMemoryHooks: Function;
  applyExpansionRomMemory: Function;
  createZ80Runtime: Function;
};

function debug80Root(): string {
  return resolve(process.env.DEBUG80_ROOT ?? DEFAULT_DEBUG80_ROOT);
}

function debug80RuntimeRoot(): string {
  if (process.env.DEBUG80_RUNTIME_ROOT) {
    return resolve(process.env.DEBUG80_RUNTIME_ROOT);
  }

  const root = debug80Root();
  return firstExistingDirectory([
    resolve(root, 'packages/debug80-runtime/dist'),
    resolve(root, 'out'),
  ], 'Debug80 runtime');
}

function debug80Mon3BundleRoot(): string {
  if (process.env.DEBUG80_MON3_BUNDLE_ROOT) {
    return resolve(process.env.DEBUG80_MON3_BUNDLE_ROOT);
  }

  const root = debug80Root();
  return firstExistingDirectory([
    resolve(root, 'apps/debug80-vscode/resources/bundles/tec1g/mon3/v1'),
    resolve(root, 'resources/bundles/tec1g/mon3/v1'),
  ], 'Debug80 MON3 bundle');
}

function debug80Mon3BundlePath(filename: string): string {
  const path = resolve(debug80Mon3BundleRoot(), filename);
  if (!existsSync(path)) {
    throw new Error(`Debug80 MON3 bundle file not found: ${path}`);
  }
  return path;
}

function loadExpansionRomImage(path: string): {
  banks: Uint8Array[];
  memory: Uint8Array;
} {
  const bytes = readFileSync(path);
  if (bytes.length !== 9 * 0x4000) {
    throw new Error(
      `invalid TECM8 expansion ROM size ${bytes.length}; expected nine 16 KiB banks`,
    );
  }
  const image = new Uint8Array(bytes);
  const banks = Array.from(
    { length: image.length / 0x4000 },
    (_, index) => image.slice(index * 0x4000, (index + 1) * 0x4000),
  );
  const memory = new Uint8Array(0x10000);
  memory.set(banks[0] ?? [], 0x8000);
  memory.set(banks[1] ?? [], 0xc000);
  return { banks, memory };
}

async function loadDebug80RuntimeModules(): Promise<Debug80RuntimeModules> {
  const [tec1gRuntime, tec1gMemory, z80Runtime] = await Promise.all([
    importRuntimeModule('platforms/tec1g/runtime.js'),
    importRuntimeModule('platforms/tec1g/tec1g-memory.js'),
    importRuntimeModule('z80/runtime.js'),
  ]);

  return {
    createTec1gRuntime: requiredExport(tec1gRuntime, 'createTec1gRuntime'),
    createTec1gMemoryHooks: requiredExport(tec1gMemory, 'createTec1gMemoryHooks'),
    applyExpansionRomMemory: requiredExport(tec1gMemory, 'applyExpansionRomMemory'),
    createZ80Runtime: requiredExport(z80Runtime, 'createZ80Runtime'),
  };
}

async function loadDebug80Z80Runtime(): Promise<{ createZ80Runtime: Function }> {
  const z80Runtime = await importRuntimeModule('z80/runtime.js');
  return {
    createZ80Runtime: requiredExport(z80Runtime, 'createZ80Runtime'),
  };
}

function firstExistingDirectory(candidates: string[], description: string): string {
  const match = candidates.find((candidate) => existsSync(candidate));
  if (match) {
    return match;
  }
  throw new Error(
    `${description} not found. Checked:\n${candidates.map((candidate) => `- ${candidate}`).join('\n')}`,
  );
}

async function importRuntimeModule(relativePath: string): Promise<Record<string, unknown>> {
  const path = resolve(debug80RuntimeRoot(), relativePath);
  if (!existsSync(path)) {
    throw new Error(`Debug80 runtime module not found: ${path}`);
  }
  return import(pathToFileURL(path).href) as Promise<Record<string, unknown>>;
}

function requiredExport(module: Record<string, unknown>, name: string): Function {
  const value = module[name];
  if (typeof value !== 'function') {
    throw new Error(`Debug80 runtime module does not export ${name}`);
  }
  return value;
}

module.exports = {
  debug80Root,
  debug80RuntimeRoot,
  debug80Mon3BundleRoot,
  debug80Mon3BundlePath,
  loadExpansionRomImage,
  loadDebug80RuntimeModules,
  loadDebug80Z80Runtime,
};
