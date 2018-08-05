port module Ports exposing (downloadImages, downloadProgress)

import Json.Encode exposing (Value)


port storeSession : Maybe String -> Cmd msg


port onSessionChange : (Value -> msg) -> Sub msg


port downloadImages : List String -> Cmd msg


port downloadProgress : (Value -> msg) -> Sub msg


port initMap : ( Float, Float ) -> Cmd msg


port addMarkers : List ( Float, Float ) -> Cmd msg
