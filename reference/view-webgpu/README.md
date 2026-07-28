# org.nostdb.view-webgpu

The reference viewer: a manifest and the executable behind it.

It exists to prove the viewer exchange format carries what a viewer needs, and to give an
author a complete working plugin to read. Every section of the exchange is decoded and every
one is used, so a format that had left something out would show up here as something missing.

## What it renders, and what it does not

It draws with **Canvas 2D**. It does not use WebGPU, and does not implement instanced
rendering, compute-assisted layout, level of detail, clustering, edge aggregation, or label
culling. It makes **no claim about any performance tier**.

The product contract requires all of those of a viewer meant for large graphs. This is not
that viewer, and describing it as one would be a promise nobody had measured. What it does
have is the honest refusal the contract also requires: past what it can draw it reports
`VIEW_CAPACITY_EXCEEDED` rather than crashing, and that is a fact about this renderer on this
machine rather than about the file.

Layout is a deterministic ring per connected component rather than a force simulation. A
simulation would look better and would draw the same input differently on every run, which is
the wrong trade for a reference: two runs should produce the same picture.

Disconnected components stay disconnected. Nothing is drawn between them, because nothing in
the exchange format can express a relationship the graph does not have.

## Requirements

Node 22 or newer, which is what runs `bin/nostdb-view`. A plugin's runtime is its own business
and the manifest says nothing about it — `nostdb` in the manifest is the range of *Engine*
versions this works with, which is a different question.

## What each permission here is saying

`graph_read: true` — this receives graph data through the Engine-owned exchange. It does not
receive a `.nostdb` parser and never opens the file. A viewer that parsed the container would
be a second reader of a format with exactly one.

`database_write: false` — always. The field is present rather than omitted so that a manifest
asking for `true` is refused *by name*: an author who asked has a misunderstanding worth
correcting, and silently ignoring the request would leave them believing it was granted.

`output_paths: [".nostdb/out/**"]` — a viewer that exports an image writes it here. Relative
and non-escaping, so an approval means what a reader of the manifest thought it meant.

`network_hosts: []` — a viewer renders a local graph. It has no reason to reach anything, and
listing nothing is how it says so.

## The entrypoint

`["bin/nostdb-view"]` is an argument vector, and a relative one. It is never passed through a
shell, and it names something inside this plugin — a manifest comes from a repository
somebody else wrote, and both of those rules exist because of who that somebody might be.
