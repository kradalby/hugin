module Views.Errors exposing (view)

{-| Render dismissable errors. We use this all over the place!
-}

import Html exposing (Html, div, hr, p, text)
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (onClick)


view : msg -> List String -> Html msg
view dismissErrors errors =
    if List.isEmpty errors then
        text ""

    else
        div [ class "row" ]
            [ div [ class "col-12 p-0" ]
                [ div [ onClick dismissErrors, class "alert alert-primary mb-0 rounded-0", attribute "role" "alert" ] <|
                    List.intersperse (hr [] []) <|
                        List.map
                            (\error -> p [ class "mb-0" ] [ text error ])
                            errors
                ]
            ]
