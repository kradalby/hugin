module Views.Spinner exposing (spinner)

import Html exposing (Attribute, Html, i)
import Html.Attributes exposing (class, style)


spinner : Html msg
spinner =
    i [ class "fas fa-2x fa-spinner fa-spin text-white" ]
        []
