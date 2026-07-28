# plugins Agent Instructions

## Inheritance

This repository is a child of the NostDB root superproject. The root `AGENTS.md`
at <https://github.com/nostdb/nostdb> is the governing contract.

This file only narrows the root rules for the plugin-authoring boundary. It must not weaken
any root product, safety, or ownership boundary. If this file and the root contract appear to
conflict, the root contract wins, the current valid behavior stays unchanged, and the exact
conflict is recorded in the root `IMPLEMENTATION_PROGRESS.md`.

## Language policy

Write everything in this repository in English only, regardless of the language a request is
written in.

## Ownership boundary

This repository holds the authoring surface: guidance, reference manifests, and reference
plugins.

Permitted:

- authoring guidance and examples;
- reference manifests that conform to `manifest_version`;
- reference plugins that speak the exchange protocol.

Prohibited:

- a plugin manager, registry, or installer. That exists once, in `nostdb-cli`;
- any `.nostdb` reader or writer. Only the Engine reads the binary format;
- a second copy of the manifest contract, which lives in `nostdb-spec`;
- a copy of the root PRD;
- a claim that a plugin is sandboxed, or that an unsigned plugin is safe.

## Invariants this repository must never break

- **A plugin never receives the binary format.** Graph data arrives through a versioned
  Engine-owned exchange.
- **An entrypoint is an argument vector**, relative to the plugin, never passed to a shell.
- **`database_write` is always false.** Only the Engine writes `.nostdb`.
- **A manifest is a request.** What a user approved is what execution is checked against.
- **Nothing here describes out-of-process execution as a sandbox.** The MVP does not
  implement one, and the root contract forbids claiming a sandbox that is not implemented.
  A process boundary is a real boundary and does not become a different one by being
  described warmly.

## Testing expectations

Every reference manifest must be one the contract accepts, checked against the published
fixtures rather than by inspection.

No test installs or executes a plugin. Installation must not execute plugin code, and a suite
that installed one to test installation would be executing the thing the contract exists to
keep from executing.

## Safety and external actions

- Never execute a plugin's code here.
- Never place a credential in a manifest, an example, or a fixture.
- Do not create remote repositories, add remotes, push to a new remote, publish packages,
  create releases, or modify registries without explicit user authorization.
- Do not use destructive Git commands or broad deletion.

## Stage workflow

Implementation sequencing is tracked in the root `IMPLEMENTATION_PROGRESS.md`, not here.
