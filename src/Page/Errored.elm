module Page.Errored exposing (PageLoadError(..), pageLoadError, view)

{-| The page that renders when there was an error trying to load another page,
for example a Page Not Found error.

It includes a photo I took of a painting on a building in San Francisco,
of a giant walrus exploding the golden gate bridge with laser beams. Pew pew!

-}

import Html exposing (Html, div, h1, img, main_, p, text)
import Html.Attributes exposing (alt, class, id, tabindex)
import Views.Page exposing (ActivePage)
import Http


-- MODEL --


type PageLoadError
    = PageLoadError Model


type alias Model =
    { activePage : ActivePage
    , errorType : Http.Error
    , errorMessage : String
    }


pageLoadError : ActivePage -> Http.Error -> String -> PageLoadError
pageLoadError activePage errorType errorMessage =
    PageLoadError
        { activePage = activePage
        , errorType = errorType
        , errorMessage = errorMessage
        }



-- VIEW --


view : PageLoadError -> Html msg
view (PageLoadError model) =
    main_ [ id "content", class "container", tabindex -1 ]
        [ h1 [ class "text-center pt-2 pb-3" ] [ text "Could not load page" ]
        , div [ class "row" ] [ text model.errorMessage ]
        , div [ class "row" ] [ text "Please send the url that produced this page to kradalby@kradalby.no" ]
        ]
