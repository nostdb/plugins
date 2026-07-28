#!/bin/sh
# Independent verification for plugins.
#
# This repository holds documents and manifests, so the checks are about the boundaries it
# must not cross and the claims it must not make.
set -eu
cd "$(dirname "$0")/.."

for required in README.md AGENTS.md CLAUDE.md LICENSE AUTHORING.md; do
  [ -e "$required" ] || { echo "missing required file: $required" >&2; exit 1; }
done

if [ ! -L CLAUDE.md ] || [ "$(readlink CLAUDE.md)" != "AGENTS.md" ]; then
  echo "CLAUDE.md must be a symlink to AGENTS.md" >&2
  exit 1
fi

if ! grep -q '^ *Apache License$' LICENSE; then
  echo "LICENSE must be the Apache License" >&2
  exit 1
fi

# A second manager here would mean two answers to "what is installed".
if [ -e src ] || [ -e Cargo.toml ]; then
  echo "the plugin manager exists once, in nostdb-cli" >&2
  exit 1
fi

if [ -e docs/PRD.md ] || [ -e grammar ] || [ -e fixtures ]; then
  echo "the PRD, the grammar, and the fixtures each live once, elsewhere" >&2
  exit 1
fi

# The reference viewer is an executable, so it can be wrong in ways a manifest cannot.
#
# Checked by parsing rather than by running. This repository must never execute a plugin's code,
# and that rule is not relaxed for the one plugin it happens to own: a rule that holds except for
# the code you wrote yourself is not a rule. What that leaves unverified is recorded in the root
# IMPLEMENTATION_PROGRESS.md rather than papered over.
viewer=reference/view-webgpu/bin/nostdb-view
if [ ! -x "$viewer" ]; then
  echo "$viewer must be committed executable; an entrypoint nothing can start is not one" >&2
  exit 1
fi
if ! head -1 "$viewer" | grep -q '^#!'; then
  echo "$viewer must name its interpreter, because an entrypoint is never run through a shell" >&2
  exit 1
fi
if command -v node >/dev/null 2>&1; then
  node --check "$viewer" || { echo "$viewer does not parse" >&2; exit 1; }
  echo "reference viewer: parses, and is executable"
else
  echo "reference viewer: node is absent, so it was not parsed" >&2
fi

# A viewer that claimed WebGPU or a performance tier would be claiming something nobody measured.
# The positive form again: the document a user reads must say what it does not do.
if ! grep -q 'Canvas 2D' reference/view-webgpu/README.md; then
  echo "the reference viewer must say what it renders with" >&2
  exit 1
fi
if ! grep -q 'no claim about any performance tier' reference/view-webgpu/README.md; then
  echo "the reference viewer must state that it claims no performance tier" >&2
  exit 1
fi

# The root contract forbids claiming a sandbox that is not implemented.
#
# Checked as a *positive* requirement rather than by searching for the claim. A grep for
# "sandboxed" cannot tell a document making the claim from one forbidding it, and every
# attempt to write that check has fired on the prose explaining why the claim is forbidden —
# four times across this project now. So instead: the two documents a user reads must each
# say plainly that there is no sandbox. A document that dropped the disclaimer fails here,
# and one that added a false claim would have to have dropped it first.
for document in README.md AUTHORING.md; do
  if ! grep -qiE 'not sandboxed|no sandbox|does not implement a sandbox' "$document"; then
    echo "$document must say plainly that a plugin is not sandboxed" >&2
    exit 1
  fi
done

# Every reference manifest states the fields the contract requires, and none asks to write
# the database. Checked here because a reference that broke the contract would be an example
# people copy.
for manifest in $(find reference -name 'nostdb-plugin.json' 2>/dev/null); do
  for field in manifest_version name version nostdb entrypoint protocol_version actions permissions; do
    grep -q "\"$field\"" "$manifest" || {
      echo "$manifest states no $field" >&2
      exit 1
    }
  done
  if grep -qE '"database_write"[[:space:]]*:[[:space:]]*true' "$manifest"; then
    echo "$manifest asks to write the database; only the Engine writes .nostdb" >&2
    exit 1
  fi
  if grep -qE '"command"[[:space:]]*:[[:space:]]*"' "$manifest"; then
    echo "$manifest states a command as a string; an entrypoint is an argument vector" >&2
    exit 1
  fi
  echo "manifest: $manifest conforms"
done

echo "plugins verification passed"
