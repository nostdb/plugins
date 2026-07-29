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

## Repository layout

A plugin lives at `plugins/<directory>/`, with `nostdb-plugin.json` at its own top level, and every
plugin is declared in `nostdb.plugins.json` at the repository root.

The index is what makes this repository installable: `plugin_install_version` 2 recognises a plugin
source by that file rather than by finding a manifest somewhere inside a tree. A plugin on disk that
the index does not declare is one nobody can install, and everything else about it looks right — so
`scripts/verify-repository.sh` refuses both directions, an index naming a directory that is not there
and a directory the index does not name.

The name in the index is what a caller's `#fragment` writes. It need not equal the manifest's declared
name, and the manifest's name is still what an installation records.

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

**No test installs a plugin, and no test executes an installed one.** Installation must not
execute plugin code, and a suite that installed one to test installation would be executing the
thing the contract exists to keep from executing.

A reference plugin's own suite **may** run the code in this repository, against fixtures it was
given. That is a different act: nothing is installed, nothing is fetched, and what runs is code
this repository authored and can read. The rule exists to keep installation from executing a
stranger's code, not to keep an author from testing their own — and a reference nobody can test
is one whose correctness is a claim rather than a result.

A reference plugin that reads a published contract must be checked against that contract's
published fixtures, passed in through `NOSTDB_SPEC_FIXTURES`, and must say so when they are
absent rather than reporting a pass it did not earn.

## Safety and external actions

- Never execute an *installed* plugin here. A reference plugin's own suite may run the code in
  this repository; see the testing expectations above.
- Never place a credential in a manifest, an example, or a fixture.
- Do not create remote repositories, add remotes, push to a new remote, publish packages,
  create releases, or modify registries without explicit user authorization.
- Do not use destructive Git commands or broad deletion.

## Stage workflow

Implementation sequencing is tracked in the root `IMPLEMENTATION_PROGRESS.md`, not here.
