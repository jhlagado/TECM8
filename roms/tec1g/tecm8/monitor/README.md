# TECM8 Monitor ROM Source

This directory contains the project-local TECM8 fixed monitor ROM source. It was
seeded from Debug80's bundled TEC-1G MON-3 v1 source tree, which corresponds to
the upstream MON3 BC25 / v1.6 ROM.

`monitor.asm` is the active Debug80 entry source. It includes `monitor.main.asm`, and
the rest of the MON-3 include graph is kept beside it so TECM8 can edit and
debug the monitor locally without changing Debug80's bundled platform ROM.

Build this ROM with:

```text
npm run rom:monitor
```

or build both TECM8 ROM artifacts with:

```text
npm run rom:check
```
