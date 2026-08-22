module Data.Url exposing
    ( Url(..)
    , contentBase
    , fromString
    , rest
    , toContentUrl
    , toRoute
    , urlDecoder
    )

import Json.Decode as Decode exposing (Decoder)
import Url.Parser as Parser exposing ((</>))


{-| A path inside a Munin gallery, exactly as Munin publishes it: relative to
the gallery root, e.g. `root/2001/index.json` or `keywords/Spring.json`.

One string used to be handed straight to `Http.get`, to `img src`, and to the
router. Those want different things — the first two need an absolute path
under the mount hugin serves the gallery from, the router wants the bare
gallery path — so resolving them identically meant the same photo resolved to
a different request depending on which page you were on. Use
`toContentUrl` to fetch or render, and `toRoute` to address a page.

Everything Munin publishes is a `Url`, including `scaledPhotos[].url` and
`originalImageURL`. Those two stayed `String` when the split was introduced,
so they kept reaching `img src` unresolved — which is what left album covers
broken.

-}
type Url
    = Url String


{-| HTTP path hugin serves `--content-dir` from. Everything Munin publishes is
relative to this.
-}
contentBase : String
contentBase =
    "/content"


{-| Absolute path to fetch or render: for `Http.get` and `img src`.

Absolute rather than relative, because a relative path resolves against
whatever SPA route is currently in the address bar.

-}
toContentUrl : Url -> String
toContentUrl (Url url) =
    if String.startsWith "/" url then
        url

    else
        contentBase ++ "/" ++ url


{-| The bare gallery path, used as the key in hugin's own routes
(`/album/root/2001/index.json`). Never prefixed: a route is not a content
location.
-}
toRoute : Url -> String
toRoute (Url url) =
    url


fromString : String -> Url
fromString str =
    Url str


json : Parser.Parser (String -> a) a
json =
    Parser.custom "JSON_FILE" <|
        \segment ->
            if String.endsWith ".json" segment then
                Just segment

            else
                Nothing



-- This is stupid, but it works...


rest : Parser.Parser (List String -> a) a
rest =
    --    restHelp 10
    Parser.oneOf
        [ Parser.map (\result -> [ result ]) json
        , Parser.map (\a b -> [ a, b ])
            (Parser.string </> json)
        , Parser.map (\a b c -> [ a, b, c ])
            (Parser.string </> Parser.string </> json)
        , Parser.map (\a b c d -> [ a, b, c, d ])
            (Parser.string </> Parser.string </> Parser.string </> json)
        , Parser.map (\a b c d e -> [ a, b, c, d, e ])
            (Parser.string </> Parser.string </> Parser.string </> Parser.string </> json)
        , Parser.map (\a b c d e f -> [ a, b, c, d, e, f ])
            (Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> json
            )
        , Parser.map (\a b c d e f g -> [ a, b, c, d, e, f, g ])
            (Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> json
            )
        , Parser.map (\a b c d e f g h -> [ a, b, c, d, e, f, g, h ])
            (Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> json
            )
        , Parser.map (\a b c d e f g h i -> [ a, b, c, d, e, f, g, h, i ])
            (Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> json
            )
        , Parser.map (\a b c d e f g h i j -> [ a, b, c, d, e, f, g, h, i, j ])
            (Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> json
            )
        ]



--restHelp : Int -> Parser.Parser (List String -> a) a
--restHelp maxDepth =
--    if maxDepth < 1 then
--        Parser.map [] Parser.top
--
--    else
--        Parser.oneOf
--            [ Parser.map [] Parser.top
--            , Parser.map (\str li -> str :: li) (Parser.string </> restHelp (maxDepth - 1))
--            ]


urlDecoder : Decoder Url
urlDecoder =
    Decode.map Url Decode.string
