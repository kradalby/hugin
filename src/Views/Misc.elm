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


viewKeywords : String -> List String -> Html msg
viewKeywords name keywords =
    div [ class "col-12 col-sm-12 col-md-6 col-lg-6 col-xl-6" ]
        [ div [ class "mt-3" ] <|
            [ h5 [] [ text name ]
            , p []
                [ text <|
                    (case keywords of
                        [] ->
                            "-"

                        _ ->
                            String.join ", " keywords
                    )
                ]
            ]
        ]


viewPath : List Photo.Parent -> Html msg
viewPath parents =
    case parents of
        [] ->
            text ""

        _ ->
            div [ class "col-12 pl-2 bg-darklight" ] <|
                List.intersperse
                    (i [ class "fas fa-angle-right text-white ml-2 mr-2" ] [])
                    (List.map
                        (\parent ->
                            a [ class "text-light", Route.href (Route.Album (Url.urlToString parent.url)) ] [ text parent.name ]
                        )
                        parents
                    )
