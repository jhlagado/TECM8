const { readFileSync } = require('node:fs');

const BANK_BYTES = 0x4000;
const BANK_COUNT = 9;

function loadTec1gExpansionRomImage(path: string): {
  banks: Uint8Array[];
  memory: Uint8Array;
} {
  const bytes = new Uint8Array(readFileSync(path));
  if (bytes.length !== BANK_BYTES * BANK_COUNT) {
    throw new Error(
      `TECM8 expansion image has ${bytes.length} bytes, expected ${BANK_BYTES * BANK_COUNT}`,
    );
  }
  return {
    banks: Array.from({ length: BANK_COUNT }, (_, index) =>
      bytes.slice(index * BANK_BYTES, (index + 1) * BANK_BYTES),
    ),
    memory: new Uint8Array(0x10000),
  };
}

module.exports = { loadTec1gExpansionRomImage };
