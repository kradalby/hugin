module Views.Assets exposing (loading, notFound, placeholder, src)

import Html exposing (Attribute)
import Html.Attributes as Attr


type Image
    = Image String



-- IMAGES --
-- Elm cannot ask the bundler for an asset URL, so these used to be
-- hand-copied content hashes and silently 404'd the moment the bundler
-- changed how it hashed. The build copies src/images/ to dist/images/
-- verbatim instead, so these paths are a contract rather than a
-- checksum. Anything that needs cache-busting should be imported from
-- TypeScript with `url:` and reach Elm through a port or a flag.
-- error : Image
-- error =
--     Image "/images/error.jpg"


placeholder : Image
placeholder =
    Image "/images/placeholder.png"


notFound : Image
notFound =
    Image "/images/404.jpg"


loading : Image
loading =
    Image "/images/loading.svg"



-- USING IMAGES --


src : Image -> Attribute msg
src (Image url) =
    Attr.src url
