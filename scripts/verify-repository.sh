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

# The index, and the layout it declares.
#
# `plugin_install_version` 2 recognises a plugin repository by `nostdb.plugins.json` rather than by
# finding a `nostdb-plugin.json` somewhere inside it. So the index is what makes this repository
# installable at all, and a plugin that is not in it is one nobody can install from here — which is
# exactly the state a checker has to refuse, because everything else about such a plugin looks right.
index=nostdb.plugins.json
if [ ! -f "$index" ]; then
  echo "$index must exist; without it no engine recognises this repository as a plugin source" >&2
  exit 1
fi
if command -v node >/dev/null 2>&1; then
  node - "$index" <<'NODE' || exit 1
const fs = require("node:fs");
const path = require("node:path");
const file = process.argv[2];
let index;
try {
  index = JSON.parse(fs.readFileSync(file, "utf8"));
} catch (error) {
  console.error(`${file} is not JSON: ${error.message}`);
  process.exit(1);
}
if (index.plugin_install_version !== 2) {
  console.error(`${file} declares plugin_install_version ${index.plugin_install_version}; this layout is 2`);
  process.exit(1);
}
const declared = index.plugins;
if (!declared || typeof declared !== "object" || Array.isArray(declared)) {
  console.error(`${file} must map a name to a directory`);
  process.exit(1);
}
const names = Object.keys(declared);
if (names.length === 0) {
  console.error(`${file} declares no plugin, so this repository publishes none`);
  process.exit(1);
}
let failed = false;
for (const [name, directory] of Object.entries(declared)) {
  if (!name) {
    console.error(`${file} maps an empty name, which no source's fragment can write`);
    failed = true;
  }
  // Under `plugins/`, because that is where this repository keeps them and a checker that accepted
  // any path would let the layout drift one plugin at a time.
  if (!directory.startsWith("plugins/")) {
    console.error(`${name} maps to ${directory}; a plugin here lives under plugins/`);
    failed = true;
  }
  if (!fs.existsSync(path.join(directory, "nostdb-plugin.json"))) {
    console.error(`${name} maps to ${directory}, which holds no nostdb-plugin.json`);
    failed = true;
  }
}
// And the other direction: a plugin on disk that the index does not declare is one nobody can
// install, and nothing else about it would look wrong.
for (const entry of fs.existsSync("plugins") ? fs.readdirSync("plugins") : []) {
  const directory = path.join("plugins", entry);
  if (!fs.statSync(directory).isDirectory()) continue;
  if (!Object.values(declared).includes(directory)) {
    console.error(`${directory} exists and ${file} does not declare it, so nothing can install it`);
    failed = true;
  }
}
process.exit(failed ? 1 : 0);
NODE
  echo "index: $(node -e 'const d=require("./nostdb.plugins.json").plugins;console.log(Object.keys(d).length+" plugin(s) declared, each under plugins/")')"
fi

# The viewer's own `NAME` and `VERSION` must equal its manifest's.
#
# They are two copies of one fact, and the version drifted the moment the manifest was bumped: an install
# reported one number and the render reported another, in the same session. A viewer that misreports its
# version reports it into the exchange stream, where a caller has no other source for it.
if command -v node >/dev/null 2>&1; then
  node - <<'NODE' || exit 1
const fs = require("node:fs");
const manifest = JSON.parse(fs.readFileSync("plugins/view-webgpu/nostdb-plugin.json", "utf8"));
const source = fs.readFileSync("plugins/view-webgpu/bin/nostdb-view", "utf8");
const literal = (name) => {
  const found = source.match(new RegExp(`^const ${name} = "([^"]*)";`, "m"));
  return found?.[1];
};
let failed = false;
for (const [name, wanted] of [["NAME", manifest.name], ["VERSION", manifest.version]]) {
  const found = literal(name);
  if (found !== wanted) {
    console.error(`bin/nostdb-view declares ${name} = ${found} and the manifest says ${wanted}`);
    failed = true;
  }
}
if (failed) process.exit(1);
console.log(`viewer identity: ${manifest.name} ${manifest.version} agrees with its manifest`);
NODE
fi

# The reference viewer is an executable, so it can be wrong in ways a manifest cannot.
#
# Checked by parsing rather than by running. This repository must never execute a plugin's code,
# and that rule is not relaxed for the one plugin it happens to own: a rule that holds except for
# the code you wrote yourself is not a rule. What that leaves unverified is recorded in the root
# IMPLEMENTATION_PROGRESS.md rather than papered over.
viewer=plugins/view-webgpu/bin/nostdb-view
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

  # And run it. Nothing is installed and nothing is fetched: what runs is code this repository
  # authored, against the published fixtures the superproject passes in through
  # NOSTDB_SPEC_FIXTURES. A reference nobody can test is one whose correctness is a claim rather
  # than a result.
  #
  # The suite says so when the fixtures are absent, and the container half is then skipped. It is
  # not treated as a pass here either: root verification is where they are always present.
  # Inside the superproject the fixtures are a sibling, so a local run of this verifier checks the
  # containers without anybody having to know the variable exists. Cloned on its own there is no
  # sibling, and the suite skips and says so — which is the honest outcome rather than a silent one.
  if [ -z "${NOSTDB_SPEC_FIXTURES:-}" ] && [ -d ../nostdb-spec/fixtures ]; then
    NOSTDB_SPEC_FIXTURES=$(cd ../nostdb-spec/fixtures && pwd)
    export NOSTDB_SPEC_FIXTURES
  fi

  if ! node plugins/view-webgpu/test/viewer.test.mjs; then
    echo "the reference viewer's own suite failed" >&2
    exit 1
  fi
else
  echo "reference viewer: node is absent, so it was neither parsed nor run" >&2
fi

# A viewer that claimed WebGPU or a performance tier would be claiming something nobody measured.
# The positive form again: the document a user reads must say what it does not do.
if ! grep -q 'Canvas 2D' plugins/view-webgpu/README.md; then
  echo "the reference viewer must say what it renders with" >&2
  exit 1
fi
if ! grep -q 'no claim about any performance tier' plugins/view-webgpu/README.md; then
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
