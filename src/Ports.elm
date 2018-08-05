port module Ports exposing (downloadImages, downloadProgress, initMap)

import Json.Encode exposing (Value)


port storeSession : Maybe String -> Cmd msg


port onSessionChange : (Value -> msg) -> Sub msg


port downloadImages : List String -> Cmd msg


port downloadProgress : (Value -> msg) -> Sub msg


port initMap : List ( Float, Float ) -> Cmd msg
