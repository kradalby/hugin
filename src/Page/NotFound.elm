module Page.NotFound exposing (view)

import Html exposing (Html, div, h1, img, main_, text)
import Html.Attributes exposing (alt, class, id, tabindex)
import Views.Assets as Assets



-- VIEW --


view : { title : String, content : Html msg }
view =
    { title = "Not Found"
    , content =
        main_ [ id "content", class "container", tabindex -1 ]
            [ h1 [ class "text-center pt-2 pb-3" ] [ text "Page not found :(" ]
            , div [ class "row" ]
                [ img [ class "rounded mx-auto d-block mb-3", Assets.src Assets.notFound, alt "Christina cannot find your page :(" ] [] ]
            ]
    }
