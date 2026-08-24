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
                        |> Url.fromString
                        |> Url.toContentUrl
                        |> Expect.equal "/content/root/a.json"
            , test "prefixes a scaled photo path" <|
                \_ ->
                    Url.fromString "root/2001/2001-01-12_340.jpeg"
                        |> Url.toContentUrl
                        |> Expect.equal "/content/root/2001/2001-01-12_340.jpeg"
            , test "preserves non-ASCII album names" <|
                \_ ->
                    Url.fromString "root/2024/Håkon_har_nytt_/a.jpeg"
                        |> Url.toContentUrl
                        |> Expect.equal "/content/root/2024/Håkon_har_nytt_/a.jpeg"
            ]
        , describe "toZipUrl"
            [ test "prefixes the zip mount" <|
                \_ ->
                    Url.fromString "root/2001/index.json"
                        |> Url.toZipUrl
                        |> Expect.equal "/zip/root/2001/index.json"
            , test "handles a keyword or person path" <|
                \_ ->
                    Url.fromString "keywords/Spring.json"
                        |> Url.toZipUrl
                        |> Expect.equal "/zip/keywords/Spring.json"
            , test "preserves non-ASCII collection names" <|
                \_ ->
                    Url.fromString "keywords/Midtøsten.json"
                        |> Url.toZipUrl
                        |> Expect.equal "/zip/keywords/Midtøsten.json"
            , test "is absolute, so it does not resolve against the current route" <|
                \_ ->
                    Url.fromString "root/2001/index.json"
                        |> Url.toZipUrl
                        |> String.startsWith "/"
                        |> Expect.equal True
            , test "keeps the mount when the path is already rooted" <|
                \_ ->
                    Url.fromString "/root/2001/index.json"
                        |> Url.toZipUrl
                        |> Expect.equal "/zip/root/2001/index.json"
            , -- One string, three meanings: resolved as content this serves
              -- the album's JSON as a .zip, as a route it 404s.
              test "is distinct from a content url and a route" <|
                \_ ->
                    let
                        url =
                            Url.fromString "root/Misc/index.json"
                    in
                    Expect.equal
                        { zip = "/zip/root/Misc/index.json"
                        , content = "/content/root/Misc/index.json"
                        , route = "root/Misc/index.json"
                        }
                        { zip = Url.toZipUrl url
                        , content = Url.toContentUrl url
                        , route = Url.toRoute url
                        }
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
