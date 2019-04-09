module Loading exposing (error, icon, slowThreshold)

{-| A loading spinner icon.
-}

import Html exposing (Attribute, Html, text)
import Html.Attributes exposing (alt, height, src, width)
import Process
import Task exposing (Task)


icon : Html msg
icon =
    -- TODO: Use font awesome
    text ""


error : String -> Html msg
error str =
    Html.text ("Error loading " ++ str ++ ".")


slowThreshold : Task x ()
slowThreshold =
    Process.sleep 500
