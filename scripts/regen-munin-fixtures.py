#!/usr/bin/env python3
"""Regenerate tests/Fixtures/MuninOutput.elm from a Munin gallery.

The Elm decoder tests run against real Munin output rather than hand-written
JSON, because hand-written JSON only proves hugin agrees with itself.

Copying by hand went stale exactly as you would expect: the fixture carried
`"next": "content/root/..."` long after every other URL had lost the prefix,
and nothing failed. Hence a script rather than a manual copy — the reformatting
is what invites mistakes.

Run it whenever Munin's published format changes. Nothing enforces that from
CI: pinning a Munin revision would only freeze the fixture against that
revision, so it would go green and stay green while Munin moved on. Galleries
are regenerated with a current Munin, so the fixture is refreshed the same way.

Usage:
    scripts/regen-munin-fixtures.py <munin-content-dir> [output.elm]

where <munin-content-dir> is Munin's generated gallery (its `targetFolder`,
holding `root/` and `keywords/`) — e.g. munin's own `example/content`.
"""

import json
import pathlib
import sys

# Chosen to cover the shapes hugin decodes, not for breadth: a nested
# sub-album, a photo carrying scaledPhotos/originalImageURL and the cyclic
# previous/next links, and a keyword page.
FIXTURES = [
    (
        "albumIndexJson",
        "root/2024/index.json",
        "an album index with a nested sub-album",
    ),
    (
        "photoJson",
        "root/Misc/portrait_mm.json",
        "a single photo: scaledPhotos, originalImageURL, and the cyclic previous/next links",
    ),
    (
        "keywordJson",
        "keywords/Spring.json",
        "a keyword page",
    ),
]

HEADER = '''module Fixtures.MuninOutput exposing (albumIndexJson, keywordJson, photoJson)

{-| Real Munin output, copied verbatim from munin's `example/content` gallery.

Hand-written JSON would only ever prove that hugin's decoders agree with
hugin's idea of the format. These fixtures make the decoder tests fail if
Munin's published shape drifts, which is the half of the contract hugin cannot
see from its own repository.

Do not edit by hand. Regenerate with `scripts/regen-munin-fixtures.py` against
a Munin checkout whenever Munin's published format changes.

-}
'''


def elm_string(text: str) -> str:
    """Escape a JSON document for an Elm triple-quoted string."""
    return text.replace("\\", "\\\\").replace('"""', '\\"\\"\\"')


def render(content_dir: pathlib.Path) -> str:
    parts = [HEADER]

    for name, relative, doc in FIXTURES:
        source = content_dir / relative
        if not source.is_file():
            sys.exit(
                f"{source} not found.\n"
                f"Expected a Munin gallery (a targetFolder holding root/ and keywords/)."
            )

        # Re-dumped rather than copied byte-for-byte so the fixture is readable
        # in review and diffs line by line. sort_keys matches Munin's own
        # .sortedKeys encoder, so the ordering is not invented here.
        pretty = json.dumps(
            json.loads(source.read_text()),
            indent=2,
            ensure_ascii=False,
            sort_keys=True,
        )

        parts.append(
            f'''
{{-| `{relative}` — {doc}.
-}}
{name} : String
{name} =
    """
{elm_string(pretty)}
"""
'''
        )

    return "\n".join(parts)


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)

    content_dir = pathlib.Path(sys.argv[1])
    output = pathlib.Path(
        sys.argv[2] if len(sys.argv) > 2 else "tests/Fixtures/MuninOutput.elm"
    )

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render(content_dir))
    print(f"wrote {output} from {content_dir}")


if __name__ == "__main__":
    main()
