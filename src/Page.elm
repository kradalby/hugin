module Page exposing (Page(..), view)

{-| The frame around a typical page - that is, the header and footer.
-}

import Browser exposing (Document)
import Data.Url
import Html exposing (Html, a, div, footer, nav, text)
import Html.Attributes exposing (class, href)


type Page
    = Other
    | Album Data.Url.Url
    | SlideShow Data.Url.Url
    | Photo Data.Url.Url
    | Keyword Data.Url.Url
    | Locations Data.Url.Url


view : Page -> { title : String, content : Html msg } -> Document msg
view page { title, content } =
    { title = title ++ " - Hugin"
    , body =
        [ viewHeader page
        , content
        , viewFooter
        ]
    }


viewHeader : Page -> Html msg
viewHeader _ =
    nav [ class "navbar navbar-expand-md navbar-dark bg-dark pl-1" ]
        [ a [ class "navbar-brand flexiday-logo", href "#" ]
            [ text "" ]
        , div [ class "ml-auto row" ]
            [ div [ class "container" ]
                []
            ]
        ]


viewFooter : Html msg
viewFooter =
    footer [ class "footer" ]
        [ div [ class "container-fluid" ]
            [ div [ class "row" ]
                [ div [ class "col-sm-8 text-muted" ]
                    [ a [ href "https://github.com/kradalby/hugin" ] [ text "Hugin" ]
                    , text " is made with "
                    , a [ href "http://elm-lang.org" ] [ text "Elm " ]
                    , text "by "
                    , a [ href "https://kradalby.no" ] [ text " Kristoffer Dalby" ]
                    , text " backend is generated by "
                    , a [ href "https://github.com/kradalby/munin" ] [ text "Munin" ]
                    ]
                , div [ class "col-sm-4 text-muted text-right" ]
                    [ text
                        "Copyright 2019"
                    ]
                ]
            ]
        ]
