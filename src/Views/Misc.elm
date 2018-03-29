module Views.Misc exposing (viewKeywords, viewPath)

{-| Assets, such as images, videos, and audio. (We only have images for now.)

We should never expose asset URLs directly; this module should be in charge of
all of them. One source of truth!

-}

import Html exposing (..)
import Html.Attributes exposing (..)
import Data.Photo as Photo exposing (Photo)
import Data.Url as Url exposing (Url)
import Route exposing (Route)


viewKeywords : String -> List Photo.KeywordPointer -> Html msg
viewKeywords name keywords =
    let
        links =
            List.intersperse (text ", ") <|
                List.map
                    (\keyword ->
                        a
                            [ class "", Route.href (Route.Keyword (Url.urlToString keyword.url)) ]
                            [ text keyword.name ]
                    )
                    (List.sortBy .name keywords)
    in
        div [ class "col-12 col-sm-12 col-md-6 col-lg-6 col-xl-6" ]
            [ div [ class "mt-3" ] <|
                [ h5 [] [ text name ]
                ]
                    ++ links
            ]


viewPath : List Photo.Parent -> Html msg
viewPath parents =
    case parents of
        [] ->
            text ""

        _ ->
            div [ class "col-11 pl-2" ] <|
                List.intersperse
                    (i [ class "fas fa-angle-right text-white ml-2 mr-2" ] [])
                    (List.map
                        (\parent ->
                            a [ class "text-light", Route.href (Route.Album (Url.urlToString parent.url)) ] [ text parent.name ]
                        )
                        parents
                    )
