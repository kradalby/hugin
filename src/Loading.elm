module Loading exposing (error, icon, slowThreshold)

{-| A loading spinner icon.
-}

import Html exposing (Html, img)
import Html.Attributes exposing (alt, class)
import Process
import Task exposing (Task)
import Views.Assets as Assets


icon : Html msg
icon =
    img [ class "rounded mx-auto d-block mt-3", Assets.src Assets.loading, alt "Loading..." ] []


error : String -> Html msg
error str =
    Html.text ("Error loading " ++ str ++ ".")


slowThreshold : Task x ()
slowThreshold =
    Process.sleep 500
