module Views.Page exposing (ActivePage(..), bodyId, frame)

{-| The frame around a typical page - that is, the header and footer.
-}

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Lazy exposing (lazy2)
import Route exposing (Route)
import Util exposing ((=>))
import Views.Spinner exposing (spinner)
import Data.Url


{-| Determines which navbar link (if any) will be rendered as active.

Note that we don't enumerate every page here, because the navbar doesn't
have links for every page. Anything that's not part of the navbar falls
under Other.

-}
type ActivePage
    = Other
    | Album Data.Url.Url
    | Photo Data.Url.Url
    | Keyword Data.Url.Url
    | Locations Data.Url.Url


{-| Take a page's Html and frame it with a header and footer.

The caller provides the current user, so we can display in either
"signed in" (rendering username) or "signed out" mode.

isLoading is for determining whether we should show a loading spinner
in the header. (This comes up during slow page transitions.)

-}
frame : Bool -> ActivePage -> Html msg -> Html msg
frame isLoading page content =
    div [ class "page-frame" ]
        [ viewHeader page isLoading
        , content
        , viewFooter
        ]


viewHeader : ActivePage -> Bool -> Html msg
viewHeader page isLoading =
    nav [ class "navbar navbar-expand-md navbar-dark bg-dark pl-1" ]
        [ a [ class "navbar-brand flexiday-logo", href "#" ]
            [ text "" ]
        , div [ class "ml-auto row" ]
            [ div [ class "container" ]
                [ lazy2 Util.viewIf isLoading spinner ]
            ]
        ]


viewFooter : Html msg
viewFooter =
    footer [ class "footer" ]
        [ div [ class "container-fluid" ]
            [ div [ class "row" ]
                [ div [ class "col-sm-8 text-muted" ]
                    [ a [ href "https://github.com/kradalby/hugin" ] [ text "Hugin" ]
                    , text " is made with <3 in "
                    , a [ href "http://elm-lang.org" ] [ text "Elm " ]
                    , text "by "
                    , a [ href "https://kradalby.no" ] [ text " Kristoffer Dalby" ]
                    , text " backend powered by "
                    , a [ href "https://github.com/kradalby/munin" ] [ text "Munin" ]
                    ]
                , div [ class "col-sm-4 text-muted text-right" ]
                    [ text
                        "Copyright 2018"
                    ]
                ]
            ]
        ]


navbarLink : ActivePage -> Route -> List (Html msg) -> Html msg
navbarLink page route linkContent =
    li [ classList [ ( "nav-item", True ), ( "active", isActive page route ) ] ]
        [ a [ class "nav-link", Route.href route ] linkContent ]


isActive : ActivePage -> Route -> Bool
isActive page route =
    case ( page, route ) of
        ( Album pageUrl, Route.Album routeUrl ) ->
            (Data.Url.urlToString pageUrl) == routeUrl

        ( Photo pageUrl, Route.Photo routeUrl ) ->
            (Data.Url.urlToString pageUrl) == routeUrl

        _ ->
            False


{-| This id comes from index.html.

The Feed uses it to scroll to the top of the page (by ID) when switching pages
in the pagination sense.

-}
bodyId : String
bodyId =
    "page-body"
