module Views.Misc exposing (viewKeywords)

{-| Assets, such as images, videos, and audio. (We only have images for now.)

We should never expose asset URLs directly; this module should be in charge of
all of them. One source of truth!

-}

import Html exposing (..)
import Html.Attributes exposing (..)


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
