port module Ports exposing (httpError, initMap, requestFullscreen)


port initMap : ( String, List ( Float, Float ) ) -> Cmd msg


port httpError : String -> Cmd msg


port requestFullscreen : () -> Cmd msg
