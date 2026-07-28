# Writing a NostDB plugin

Anyone may author a compatible plugin. This describes what one is and what it can expect —
not what makes one trustworthy, which is a question this project does not answer for you.

## What a plugin is

An executable, described by a `nostdb-plugin.json` manifest, that the CLI starts out of
process and talks to over a versioned exchange.

It is not linked into the Engine, does not share its memory, and does not outlive the request
it was started for. Those are real properties and they are the ones on offer.

## What a plugin is not

**It is not sandboxed.** The MVP does not implement a sandbox and does not claim one. A
plugin runs as your user, with your files, and the process boundary is the whole of the
isolation. Install one the way you would install any other program somebody else wrote.

Nothing here says an unsigned third-party plugin is safe, and a signature scheme is not
implemented either. If that matters for your deployment, the honest answer today is to read
what you install.

## What you get, and what you never get

You receive authorized graph data through the exchange stream. You never receive:

- a `.nostdb` parser API, or the file. Only the Engine reads the binary format;
- a shell. Your entrypoint is an argument vector, and it names a path inside your plugin;
- a permission you did not declare. What you ask for is what a user approves, and what they
  approved is what execution is checked against.

## Declaring what you need

Ask for the least that works, because every entry is something a user has to decide about and
a long list is one people approve without reading.

- `output_paths` are project-relative globs with no `..` segment. An escaping path is refused
  rather than clamped, so you find out at install time rather than discovering later that
  your writes went somewhere adjacent;
- `network_hosts` is an allowlist and empty by default. `*` is refused: a plugin wanting the
  whole network is asking for something nobody can meaningfully approve;
- `database_write` must be `false`. Propose changes through the Engine instead.

## Versions

`nostdb` is a range of Engine versions you work with, and `protocol_version` is the exchange
you speak. They move separately — an Engine release does not imply a new exchange, and a new
exchange does not imply an Engine release.

State both honestly. A range wider than you have tested is a promise you have not kept yet.

## Publishing

A plugin is installed from GitHub:

```text
https://github.com/<owner>/<repository>[?ref=<git-ref>][#<subdirectory>]
```

With no ref, the manager resolves the default branch **once** and records the commit. Your
users do not follow your branch: they pin what they installed, and moving your branch does
not move them. That is deliberate, and it means a fix reaches them only when they ask for it.

One repository may hold several plugins, each in its own subdirectory.

## What installation does, and does not do

It resolves, fetches, checks paths and archive limits, reads your manifest, verifies digests,
records what was approved — and stops. **It does not run your code.** Your plugin executes
later, when an action needs it, and only if its digests still match what was recorded.

That means an install that succeeds tells a user nothing about whether your plugin works. It
tells them what your plugin *is*.
