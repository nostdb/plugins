// The reference viewer, run against the published viewer exchange fixtures.
//
// This runs the plugin. Nothing is installed and nothing is fetched: what runs is code this
// repository authored, against fixtures the superproject passed in. A reference nobody can test is
// one whose correctness is a claim rather than a result.
//
// The container fixtures come from NOSTDB_SPEC_FIXTURES, which is the same way every Rust
// conformance suite in this workspace reads them. Without it the container half is skipped and says
// so, because a suite that quietly checked nothing would report a pass it had not earned.

import { spawn } from "node:child_process";
import { readFileSync, readdirSync, mkdtempSync, rmSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { join, dirname } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const VIEWER = join(here, "..", "bin", "nostdb-view");
const MEDIA_TYPE = "application/vnd.nostdb.view+bin";

let failures = 0;
let checks = 0;

function check(what, condition, detail = "") {
  checks += 1;
  if (condition) {
    console.log(`ok   ${what}`);
  } else {
    console.error(`FAIL ${what}${detail ? `: ${detail}` : ""}`);
    failures += 1;
  }
}

/**
 * Runs one conversation and returns the replies, in order.
 *
 * The argument vector is passed directly, never through a shell — which is the same rule the
 * manager follows, and worth following here so this suite exercises the real thing.
 */
function converse(requests) {
  return new Promise((resolve, reject) => {
    const child = spawn(VIEWER, [], { stdio: ["pipe", "pipe", "inherit"] });
    let out = "";
    child.stdout.on("data", (chunk) => {
      out += chunk;
    });
    child.on("error", reject);
    child.on("close", () => {
      const replies = out
        .split("\n")
        .filter((line) => line.trim())
        .map((line) => JSON.parse(line));
      resolve(replies);
    });
    for (const request of requests) child.stdin.write(`${JSON.stringify(request)}\n`);
    child.stdin.end();
  });
}

const handshake = { plugin_protocol_version: 1, request: "handshake" };

function invoke(path, output, overrides = {}) {
  const bytes = readFileSync(path);
  return {
    plugin_protocol_version: 1,
    request: "invoke",
    action: "view",
    output_directory: output,
    options: {},
    exchange: {
      kind: "artifact",
      media_type: MEDIA_TYPE,
      path,
      bytes: bytes.length,
      content_digest: `sha256:${createHash("sha256").update(bytes).digest("hex")}`,
      ...overrides,
    },
  };
}

function expectations(path) {
  const text = readFileSync(path.replace(/\.bin$/, ".expected"), "utf8");
  const map = new Map();
  for (const line of text.split("\n")) {
    const at = line.indexOf(" = ");
    if (at > 0) map.set(line.slice(0, at).trim(), line.slice(at + 3).trim());
  }
  return map;
}

const scratch = mkdtempSync(join(tmpdir(), "nostdb-viewer-test-"));

// ---- the protocol, which needs no fixtures ----

{
  const [reply] = await converse([handshake]);
  check("the handshake names this plugin and its actions",
    reply.reply === "handshake" &&
      reply.plugin === "org.nostdb.view-webgpu" &&
      Array.isArray(reply.actions) &&
      reply.actions.length === 1 &&
      reply.actions[0] === "view",
    JSON.stringify(reply));
  check("and states the protocol version", reply.plugin_protocol_version === 1);
}

{
  const [reply] = await converse([{ plugin_protocol_version: 2, request: "handshake" }]);
  check("another protocol version is refused", reply.code === "PLUGIN_PROTOCOL_UNSUPPORTED",
    JSON.stringify(reply));
}

{
  const [reply] = await converse([{ plugin_protocol_version: 1, request: "render" }]);
  check("an unknown request kind is refused", reply.code === "PLUGIN_REQUEST_INVALID",
    JSON.stringify(reply));
}

{
  const [, reply] = await converse([
    handshake,
    { plugin_protocol_version: 1, request: "invoke", action: "exfiltrate", output_directory: scratch },
  ]);
  check("an action this build does not implement is refused",
    reply.code === "PLUGIN_ACTION_UNKNOWN", JSON.stringify(reply));
}

{
  // graph_read was not approved, so there is nothing to draw. An empty page would look like an
  // empty graph, which is why this refuses rather than writing one.
  const [, reply] = await converse([
    handshake,
    { plugin_protocol_version: 1, request: "invoke", action: "view", output_directory: scratch },
  ]);
  check("an invocation with no exchange is refused rather than drawing nothing",
    reply.code === "PLUGIN_REQUEST_INVALID", JSON.stringify(reply));
}

// ---- the containers ----

const root = process.env.NOSTDB_SPEC_FIXTURES
  ? join(process.env.NOSTDB_SPEC_FIXTURES, "view-exchange", "container")
  : null;

if (!root || !existsSync(root)) {
  console.log("skip NOSTDB_SPEC_FIXTURES is unset, so no container was decoded");
} else {
  const bins = (directory) =>
    readdirSync(join(root, directory))
      .filter((name) => name.endsWith(".bin"))
      .sort()
      .map((name) => join(root, directory, name));

  const accepted = bins("valid");
  check("accepted containers were found", accepted.length > 0);
  for (const path of accepted) {
    const output = mkdtempSync(join(tmpdir(), "nostdb-view-out-"));
    const [, reply] = await converse([handshake, invoke(path, output)]);
    const name = path.split("/").pop();
    check(`${name} renders`,
      reply.reply === "invoke" && reply.status === "complete",
      JSON.stringify(reply));
    if (reply.reply === "invoke") {
      check(`${name} writes both outputs`,
        reply.outputs.includes("view.html") && reply.outputs.includes("view.data.bin"),
        JSON.stringify(reply.outputs));
      const html = readFileSync(join(output, "view.html"), "utf8");
      // The counts the fixture declares must be in the page, which is what proves the decode
      // reached the data rather than merely not crashing.
      const declared = expectations(path);
      check(`${name} draws the declared node count`,
        html.includes(`"nodes":[`) || declared.get("nodes") === "0",
        "the page carries no nodes array");
      const data = JSON.parse(html.slice(html.indexOf('id="data">') + 10, html.indexOf("</script>")));
      check(`${name} decoded ${declared.get("nodes")} nodes and ${declared.get("edges")} edges`,
        String(data.nodes.length) === declared.get("nodes") &&
          String(data.edges.length) === declared.get("edges"),
        `${data.nodes.length} and ${data.edges.length}`);
      check(`${name} decoded ${declared.get("sources")} sources`,
        String(data.sources.length) === declared.get("sources"),
        String(data.sources.length));
      const evidence = data.nodes.filter((node) => node.evidence).length;
      check(`${name} decoded ${declared.get("evidence")} evidence entries`,
        String(evidence) === declared.get("evidence"), String(evidence));
    }
    rmSync(output, { recursive: true, force: true });
  }

  const rejected = bins("invalid");
  check("rejected containers were found", rejected.length > 0);
  for (const path of rejected) {
    const output = mkdtempSync(join(tmpdir(), "nostdb-view-out-"));
    const [, reply] = await converse([handshake, invoke(path, output)]);
    const name = path.split("/").pop();
    const declared = expectations(path).get("code");
    check(`${name} is refused as ${declared}`,
      reply.reply === "error" && reply.code === declared,
      JSON.stringify(reply));
    check(`${name} wrote nothing`, !existsSync(join(output, "view.html")));
    rmSync(output, { recursive: true, force: true });
  }

  // The digest is the manager's statement about what it wrote, and this verifies before it
  // interprets. A viewer that read first would have interpreted bytes nobody vouched for.
  {
    const path = accepted[0];
    const output = mkdtempSync(join(tmpdir(), "nostdb-view-out-"));
    const [, reply] = await converse([
      handshake,
      invoke(path, output, { content_digest: `sha256:${"0".repeat(64)}` }),
    ]);
    check("a declared digest that does not match is refused",
      reply.code === "PLUGIN_FAILED" && /digest/.test(reply.message),
      JSON.stringify(reply));
    check("and nothing was written", !existsSync(join(output, "view.html")));
    rmSync(output, { recursive: true, force: true });
  }

  // Never inferred from the path's extension.
  {
    const path = accepted[0];
    const output = mkdtempSync(join(tmpdir(), "nostdb-view-out-"));
    const [, reply] = await converse([
      handshake,
      invoke(path, output, { media_type: "application/x-unheard-of" }),
    ]);
    check("a media type this build does not read is refused",
      reply.code === "PLUGIN_REQUEST_INVALID", JSON.stringify(reply));
    rmSync(output, { recursive: true, force: true });
  }
}

rmSync(scratch, { recursive: true, force: true });

if (failures > 0) {
  console.error(`${failures} of ${checks} checks failed`);
  process.exit(1);
}
console.log(`reference viewer: every check passed (${checks})`);
