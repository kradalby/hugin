module Request.Helpers exposing (rootUrl)

{-| Entry point into a Munin gallery.

Munin writes the album tree under its configured gallery name (`root` by
default) inside the directory hugin serves as `--content-dir`. That makes this
a gallery-relative path like every other URL in the data, so it goes through
`Data.Url` to become either a request or a route.

This used to read `content/root/index.json`, which quietly required Munin's
`targetFolder` to be named `content`: the prefix Munin stamps into every
published URL had to match the mount hugin serves. Munin now publishes
gallery-relative URLs, so the mount name is hugin's business alone
(`Data.Url.contentBase`).

`apiUrl` also lived here and prefixed a `/`, but it was never applied to URLs
coming from the gallery data. `Data.Url.toContentUrl` does that job now.

-}


rootUrl : String
rootUrl =
    "root/index.json"
