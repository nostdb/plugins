# org.nostdb.view-webgpu

The reference viewer manifest. There is no viewer behind it yet; this exists so an author
can see a complete, valid manifest and so the manifest contract has something real to
validate against.

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
