module Loading exposing (error, icon, slowThreshold)

{-| A loading spinner icon.
-}

import Html exposing (Attribute, Html, i, text)
import Html.Attributes exposing (alt, class, height, src, width)
import Process
import Task exposing (Task)


icon : Html msg
icon =
    i [ class "fas fa-2x fa-spinner fa-spin text-black" ] []


error : String -> Html msg
error str =
    Html.text ("Error loading " ++ str ++ ".")


slowThreshold : Task x ()
slowThreshold =
    Process.sleep 500
