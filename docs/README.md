# TECM8 Documentation

TECM8 is a self-hosted Z80 Assembly development environment for the TEC-1G. The
first customer-facing target is an early Turbo Pascal-style project workflow on
the machine itself: a remembered main file, direct named-file editing, short
`edit`/`asm`/`run` commands, and return to the prompt.

The long-term product shape is a small TECM8 operating system layered first on
MON3 and later on a MON3-compatible TECM8 BIOS profile. The shell is the system
personality and front door: it owns the project context and launches banked ROM
tools such as the editor, assembler, runner, and later debugger. MON3 remains
the hardware service layer for now, while TECM8 gradually replaces optional
monitor UI and peripheral code with resident shell and tool-support services.

The preferred source extension is `.ASM`. `.Z80` remains supported for imported
ASM80-era code, but TECM8 examples should lead with `.ASM`. The advanced goal is
a source-aware debugger with source maps, breakpoints, stepping, and register
display.

The name is spelled `TECM8` and pronounced "TecMate": a companion for the TEC-1.
Use `TM8` where a short three-character identifier is needed.

Install the maintained proof/tooling dependencies from the repo root:

```text
npm install
```

Useful project commands:

```text
npm run z80:size
npm run check
npm run proof:project-config
npm run proof:project-config:storage
npm run proof:shell-commands
npm run proof:storage:check
npm run audit:storage
npm run quality
```

Milestone history is tracked in the root [Changelog](../CHANGELOG.md). TECM8
uses version tags for reviewed, pushed, locally verified Z80/editor milestones;
the npm package metadata is incidental to the host tooling and is not the main
release surface.

Start here:

- [Live Roadmap](roadmap.md)
- [Codebase Tour](codebase.md)
- [Virtual Filesystem](virtual-filesystem.md)
- [TEC-Side Shell Command Contract](shell-command-contract.md)
- [TECM8 AZM Style Guide](azm-style-guide.md)
- [AZM Adoption Opportunities](azm-adoption-opportunities.md)
- [AZM Practical Feedback](azm-practical-feedback.md)
- [AZM Register Contract Feedback](azm-register-contract-feedback.md)
- [Z80 Space-Saving Opportunities](z80-space-saving-opportunities.md)
- [Editor Design](editor-design.md)
- [Editor Command Policy And Compaction Inventory](editor-command-policy.md)
- [Editor Rolling Source Window](editor-rolling-window.md)
- [Editor Block Operations](block-operations.md)
- [Display Service Extraction Plan](display-service-extraction.md)
- [Debug80 Editor Session](debug80-editor-session.md)
- [Memory and Code Quality Manifest](memory-and-code-quality.md)
- [Code Quality Execution Plan](code-quality-remediation-plan.md)
- [TypeScript Code Quality Report](typescript-code-quality.md)
- [TECM8 BIOS API Draft](tecm8-bios-api.md)

MON3/MON3-light direction and analysis is part of the TECM8 platform work. These
documents define how the fixed ROM, banked ROM tools, display services, storage
services, and editor workflow fit together:

- [MON3-Light Platform Direction](mon3/mon3-light-platform-direction.md)
- [TECM8 ROM Artifact Plan](mon3/tecm8-rom-artifact-plan.md)
- [TecMate OS Progress](mon3/tecmate-os-progress.md)
- [TecMate ROM Space Map](mon3/tecmate-rom-space-map.md)
- [Register Contract Policy](mon3/register-contract-policy.md)
- [Monitor Register Contract Audit](mon3/monitor-register-contract-audit.md)
- [TEC-FS Storage Direction](mon3/tec-fs-direction.md)
- [MON3 Core And Auxiliary Services](mon3/core-and-auxiliary-services.md)
- [MON3 Decomposition Plan](mon3/decomposition.md)
- [MON3 Service Inventory](mon3/service-inventory.md)
- [MON3 Storage Split Report](mon3/storage-split.md)
- [MON3 GLCD Split Report](mon3/glcd-split.md)
