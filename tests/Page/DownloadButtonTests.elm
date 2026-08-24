module Page.DownloadButtonTests exposing (suite)

{-| Two properties, neither obvious from the view: the button is absent unless
the backend answered the probe, and its href resolves through the zip mount.
Resolved as content it would hand the user the album's JSON renamed `.zip`.

Tested directly rather than through each page's `view`, because a page Model
holds a `Browser.Navigation.Key` and no test can construct one.

-}

import Data.Album exposing (Album)
import Data.Keyword exposing (Keyword)
import Data.Url as Url
import Expect
import Html.Attributes as Attr
import Page.Album
import Page.Keyword
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


suite : Test
suite =
    describe "collection download button"
        [ describe "album page"
            [ test "is absent when the backend did not answer" <|
                \_ ->
                    Page.Album.viewDownloadButton albumFixture Nothing
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.tag "a" ]
                        |> Query.count (Expect.equal 0)
            , test "is present when the backend reported a size" <|
                \_ ->
                    Page.Album.viewDownloadButton albumFixture (Just { size = Just 243100000 })
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.tag "a" ]
                        |> Query.count (Expect.equal 1)
            , test "downloads through the zip mount, not the content mount" <|
                \_ ->
                    Page.Album.viewDownloadButton albumFixture (Just { size = Just 1000 })
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "a" ]
                        |> Query.has
                            [ Selector.attribute
                                (Attr.href "/zip/root/Misc/index.json")
                            ]
            , -- Without it, elm/browser's link diverter intercepts the click
              -- and Main's ClickedLink swallows it.
              test "carries the download attribute" <|
                \_ ->
                    Page.Album.viewDownloadButton albumFixture (Just { size = Just 1000 })
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "a" ]
                        |> Query.has [ Selector.attribute (Attr.download "") ]
            , test "puts the archive size in the tooltip" <|
                \_ ->
                    Page.Album.viewDownloadButton albumFixture (Just { size = Just 243100000 })
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "a" ]
                        |> Query.has
                            [ Selector.attribute
                                (Attr.title "Download album (243.1 MB)")
                            ]
            , -- A proxy that drops Content-Length on the HEAD must not remove
              -- a working feature; only the size in the tooltip is lost.
              test "renders without a size when the length was not reported" <|
                \_ ->
                    Page.Album.viewDownloadButton albumFixture (Just { size = Nothing })
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "a" ]
                        |> Query.has [ Selector.attribute (Attr.title "Download album") ]
            , -- Font Awesome rewrites the icon to an aria-hidden svg, so the
              -- link would otherwise have no accessible name at all.
              test "has an accessible name" <|
                \_ ->
                    Page.Album.viewDownloadButton albumFixture (Just { size = Just 1000 })
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "a" ]
                        |> Query.has
                            [ Selector.attribute
                                (Attr.attribute "aria-label" "Download album (1 kB)")
                            ]
            , -- The browser owns the progress UI once it starts.
              test "is an icon rather than a text label" <|
                \_ ->
                    Page.Album.viewDownloadButton albumFixture (Just { size = Just 1000 })
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "i" ]
                        |> Query.has [ Selector.class "fa-download" ]
            ]
        , describe "keyword page"
            [ test "is absent when the backend did not answer" <|
                \_ ->
                    Page.Keyword.viewDownloadButton keywordFixture Nothing
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.tag "a" ]
                        |> Query.count (Expect.equal 0)
            , -- Munin writes people into keywords/ too, so one button serves
              -- both a tag and a person page.
              test "downloads a keyword or person through the zip mount" <|
                \_ ->
                    Page.Keyword.viewDownloadButton keywordFixture (Just { size = Just 1000 })
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "a" ]
                        |> Query.has
                            [ Selector.attribute
                                (Attr.href "/zip/keywords/Martin_Peter_Meuche.json")
                            ]
            , test "carries the download attribute" <|
                \_ ->
                    Page.Keyword.viewDownloadButton keywordFixture (Just { size = Just 1000 })
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "a" ]
                        |> Query.has [ Selector.attribute (Attr.download "") ]
            , test "puts the archive size in the tooltip" <|
                \_ ->
                    Page.Keyword.viewDownloadButton keywordFixture (Just { size = Just 42653 })
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "a" ]
                        |> Query.has
                            [ Selector.attribute
                                (Attr.title "Download all photos (42.7 kB)")
                            ]
            ]
        ]


{-| Empty `photos` is irrelevant: downloadability is the server's decision,
reported through the probe, so the view has one condition rather than two that
could disagree.
-}
albumFixture : Album
albumFixture =
    { url = Url.fromString "root/Misc/index.json"
    , photos = []
    , albums = []
    , people = []
    , keywords = []
    , name = "Misc"
    , parents = []
    }


keywordFixture : Keyword
keywordFixture =
    { url = Url.fromString "keywords/Martin_Peter_Meuche.json"
    , photos = []
    , name = "Martin Peter Meuche"
    }
