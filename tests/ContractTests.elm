module ContractTests exposing (suite)

import Data.Album as Album
import Data.Keyword as Keyword
import Data.Photo as Photo
import Data.Url as Url
import Expect
import Fixtures.MuninOutput as Fixture
import Json.Decode as Decode
import Test exposing (Test, describe, test)


{-| Decodes real Munin output.

hugin's decoders are only half of a contract whose other half lives in another
repository. Testing them against hand-written JSON would prove that hugin
agrees with itself. These tests run against files copied verbatim from munin's
`example/content` gallery, so they fail if Munin's published shape drifts.

The property that matters most: every URL Munin publishes is relative to the
gallery root, and hugin resolves it to an absolute path under the mount it
serves. Munin used to stamp its own output directory name into every URL,
which forced hugin to hard-code the same name.

-}
suite : Test
suite =
    describe "Munin output contract"
        [ describe "album index"
            [ test "decodes" <|
                \_ ->
                    Decode.decodeString Album.decoder Fixture.albumIndexJson
                        |> Result.map .name
                        |> Expect.equal (Ok "2024")
            , test "album urls are gallery-relative, not rooted at Munin's output dir" <|
                \_ ->
                    Decode.decodeString Album.decoder Fixture.albumIndexJson
                        |> Result.map (.albums >> List.map (.url >> Url.toRoute))
                        |> Expect.equal
                            (Ok [ "root/2024/2024-06-21_Håkon_har_nytt_kamera/index.json" ])
            , test "album urls resolve under the content mount" <|
                \_ ->
                    Decode.decodeString Album.decoder Fixture.albumIndexJson
                        |> Result.map (.albums >> List.map (.url >> Url.toContentUrl))
                        |> Expect.equal
                            (Ok
                                [ "/content/root/2024/2024-06-21_Håkon_har_nytt_kamera/index.json" ]
                            )
            , test "no published url carries a content or gallery-name prefix" <|
                \_ ->
                    Decode.decodeString Album.decoder Fixture.albumIndexJson
                        |> Result.map (.albums >> List.map (.url >> Url.toRoute))
                        |> Result.map (List.filter (String.startsWith "content/"))
                        |> Expect.equal (Ok [])
            ]
        , describe "photo"
            [ test "decodes" <|
                \_ ->
                    Decode.decodeString Photo.decoder Fixture.photoJson
                        |> Result.map .name
                        |> Expect.equal (Ok "portrait_mm")
            , test "scaled photo urls are relative and resolve under the mount" <|
                \_ ->
                    Decode.decodeString Photo.decoder Fixture.photoJson
                        |> Result.map (.scaledPhotos >> List.map (.url >> Url.toRoute))
                        |> Result.map (List.filter (String.startsWith "/"))
                        |> Expect.equal (Ok [])
            , test "a scaled photo url becomes an absolute content url" <|
                \_ ->
                    Decode.decodeString Photo.decoder Fixture.photoJson
                        |> Result.map
                            (.scaledPhotos
                                >> List.map (.url >> Url.toContentUrl)
                                >> List.filter (String.startsWith "/content/")
                                >> List.isEmpty
                            )
                        |> Expect.equal (Ok False)
            , test "the original image url is relative" <|
                \_ ->
                    Decode.decodeString Photo.decoder Fixture.photoJson
                        |> Result.map (.originalImageURL >> Url.toRoute >> String.startsWith "/")
                        |> Expect.equal (Ok False)
            , -- The bug the screenshots showed: an album card rendered a
              -- broken image while the photos below it were fine, because
              -- covers go through `thumbnail` and photos got their src from a
              -- srcset the browser preferred. Both feed `img src`, so both
              -- have to come back absolute.
              test "thumbnail and biggest render absolute image locations" <|
                \_ ->
                    Decode.decodeString Photo.decoder Fixture.photoJson
                        |> Result.map
                            (\photo ->
                                [ Photo.thumbnail photo.scaledPhotos 300
                                , Photo.biggest photo.scaledPhotos
                                ]
                                    |> List.filter (String.startsWith "/content/root/")
                                    |> List.length
                            )
                        |> Expect.equal (Ok 2)
            , -- These two were published with the content/ prefix while every
              -- other url was relative, and both suites stayed green: Munin's
              -- walk only looked at url/originalImageURL, and these assertions
              -- did not exist. Page.Photo renders them through Url.toRoute for
              -- the prev/next arrows, so unfixed those two links pointed at
              -- /photo/content/root/... while the rest of the app was correct.
              test "previous and next are gallery-relative" <|
                \_ ->
                    Decode.decodeString Photo.decoder Fixture.photoJson
                        |> Result.map
                            (\photo ->
                                [ photo.previous, photo.next ]
                                    |> List.filterMap identity
                                    |> List.map Url.toRoute
                                    |> List.filter
                                        (\u ->
                                            String.startsWith "content/" u
                                                || String.startsWith "/" u
                                        )
                            )
                        |> Expect.equal (Ok [])
            , test "previous and next are present and point at sibling photos" <|
                \_ ->
                    Decode.decodeString Photo.decoder Fixture.photoJson
                        |> Result.map
                            (\photo ->
                                [ photo.previous, photo.next ]
                                    |> List.filterMap identity
                                    |> List.map Url.toRoute
                                    |> List.filter (String.startsWith "root/Misc/")
                                    |> List.length
                            )
                        |> Expect.equal (Ok 2)
            , test "previous and next resolve under the content mount" <|
                \_ ->
                    Decode.decodeString Photo.decoder Fixture.photoJson
                        |> Result.map
                            (\photo ->
                                [ photo.previous, photo.next ]
                                    |> List.filterMap identity
                                    |> List.map Url.toContentUrl
                                    |> List.filter (String.startsWith "/content/root/")
                                    |> List.length
                            )
                        |> Expect.equal (Ok 2)
            ]
        , describe "keyword"
            [ test "decodes" <|
                \_ ->
                    Decode.decodeString Keyword.decoder Fixture.keywordJson
                        |> Result.map .name
                        |> Expect.equal (Ok "Spring")
            , test "keyword photo urls are gallery-relative" <|
                \_ ->
                    Decode.decodeString Keyword.decoder Fixture.keywordJson
                        |> Result.map (.photos >> List.map (.url >> Url.toRoute))
                        |> Result.map (List.filter (String.startsWith "/"))
                        |> Expect.equal (Ok [])
            ]
        ]
