# testdata/gallery

Real [Munin](https://github.com/kradalby/munin) output, not hand-written.

`integration_test.go` serves `content/` through the same handler tree
production uses and requires every published URL to resolve. That is the one
property neither repo can test alone: Munin asserts its URLs are relative and
self-consistent, hugin asserts it decodes them, and both suites were green
while every thumbnail 404'd in production.

Hand-written JSON would only prove hugin agrees with itself, so this is
generated:

```bash
cd testdata/gallery
munin            # reads munin.json here; writes content/
```

`album/` is the source tree and is committed alongside `content/` on purpose —
Munin symlinks originals rather than copying them, so `originalImageURL` points
into `album/`. Drop it and those URLs stop resolving, which the test would
report as a contract failure rather than a missing fixture.

The two source images are deliberately small (~40 KB) and downscaled from
Munin's own `example/album/Misc`. Their EXIF is intact, so keyword, people and
location extraction still exercise: the gallery has eight keywords.

`munin.json` pins one resolution and `diff: false` to keep regeneration
deterministic and the tree small.

Regenerate whenever Munin's published format changes, along with
`tests/Fixtures/` (see `scripts/regen-munin-fixtures.py`) — that is a separate,
smaller copy used by the Elm decoder tests. Both come from Munin, but they
answer different questions: this one that hugin _serves_ the gallery correctly,
that one that hugin _decodes_ it correctly.
