# plugins

The NostDB plugin manifest schema, authoring guidance, and reference plugins.

**Status: scaffolding.** The manifest contract is specified in `nostdb-spec`; this holds a
reference manifest that conforms to it and the guidance for writing your own. No plugin here
does anything yet.

## What this repository is not

It is **not** a second plugin manager. The native manager exists once, in `nostdb-cli`, and
installations persist across CLI and Server processes. A registry here would mean two answers
to "what is installed", and the one a user got would depend on which surface they reached for.

It holds no `.nostdb` reader or writer. Only the Engine reads the binary format, and a plugin
receives graph data through a versioned Engine-owned exchange instead.

## Start here

- [`AUTHORING.md`](AUTHORING.md) — what a plugin is, what it gets, and what it never gets
- [`nostdb.plugins.json`](nostdb.plugins.json) — the index that makes this repository a plugin
  source, mapping each name a caller writes to the directory it lives in
- [`plugins/view-webgpu/`](plugins/view-webgpu/) — a complete, valid manifest with each
  permission explained
- the manifest contract itself, in
  [`nostdb-spec/docs/PLUGIN_MANIFEST.md`](https://github.com/nostdb/nostdb-spec/blob/main/docs/PLUGIN_MANIFEST.md)

## One thing worth reading twice

A plugin is **not sandboxed**. The MVP does not implement a sandbox and does not claim one.
A plugin runs as your user, with your files; the process boundary is the whole of the
isolation. Nothing here says an unsigned third-party plugin is safe.

## Licence

Apache-2.0. A schema nobody can implement freely is a schema with one implementation.
