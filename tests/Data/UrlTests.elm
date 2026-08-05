module Data.UrlTests exposing (suite)

import Data.Url as Url
import Expect
import Json.Decode as Decode
import Test exposing (Test, describe, test)


{-| `Data.Url` is where hugin decides what a gallery path means. The same
string is a request, an `img src`, and a route key, and conflating those is
what made photos resolve differently depending on the current page.
-}
suite : Test
suite =
    describe "Data.Url"
        [ describe "toContentUrl"
            [ test "prefixes the content mount" <|
                \_ ->
                    Url.fromString "root/2001/index.json"
                        |> Url.toContentUrl
                        |> Expect.equal "/content/root/2001/index.json"
            , test "is absolute, so it does not resolve against the current route" <|
                \_ ->
                    Url.fromString "root/2001/index.json"
                        |> Url.toContentUrl
                        |> String.startsWith "/"
                        |> Expect.equal True
            , test "handles a keywords path" <|
                \_ ->
                    Url.fromString "keywords/Spring.json"
                        |> Url.toContentUrl
                        |> Expect.equal "/content/keywords/Spring.json"
            , test "leaves an already-absolute path alone" <|
                \_ ->
                    Url.fromString "/content/root/a.json"
                        |> Url.toContentUrl
                        |> Expect.equal "/content/root/a.json"
            , test "does not double the prefix when applied to its own output" <|
                \_ ->
                    Url.fromString "root/a.json"
                        |> Url.toContentUrl
                        |> Url.contentUrl
                        |> Expect.equal "/content/root/a.json"
            ]
        , describe "contentUrl"
            [ test "prefixes a scaled photo path" <|
                \_ ->
                    Url.contentUrl "root/2001/2001-01-12_340.jpeg"
                        |> Expect.equal "/content/root/2001/2001-01-12_340.jpeg"
            , test "preserves non-ASCII album names" <|
                \_ ->
                    Url.contentUrl "root/2024/Håkon_har_nytt_/a.jpeg"
                        |> Expect.equal "/content/root/2024/Håkon_har_nytt_/a.jpeg"
            ]
        , describe "toRoute"
            [ -- A route is a page address, not a content location. Prefixing
              -- it would put /content into the address bar and break the
              -- parser, which expects the bare gallery path.
              test "leaves the gallery path bare" <|
                \_ ->
                    Url.fromString "root/2001/index.json"
                        |> Url.toRoute
                        |> Expect.equal "root/2001/index.json"
            , test "round-trips through fromString" <|
                \_ ->
                    "root/2001/index.json"
                        |> Url.fromString
                        |> Url.toRoute
                        |> Expect.equal "root/2001/index.json"
            ]
        , describe "urlDecoder"
            [ test "decodes a published gallery path" <|
                \_ ->
                    Decode.decodeString Url.urlDecoder "\"root/2001/index.json\""
                        |> Result.map Url.toRoute
                        |> Expect.equal (Ok "root/2001/index.json")
            , test "a decoded url becomes a fetchable content url" <|
                \_ ->
                    Decode.decodeString Url.urlDecoder "\"root/2001/index.json\""
                        |> Result.map Url.toContentUrl
                        |> Expect.equal (Ok "/content/root/2001/index.json")
            ]
        ]
