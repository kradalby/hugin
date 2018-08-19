port module Ports exposing (downloadImages, initMap)

import Json.Encode exposing (Value)


port storeSession : Maybe String -> Cmd msg


port onSessionChange : (Value -> msg) -> Sub msg


port downloadImages : List String -> Cmd msg


port initMap : ( String, List ( Float, Float ) ) -> Cmd msg
