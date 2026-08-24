port module Ports exposing (analytics, httpError, initMap, requestFullscreen)


port initMap : ( String, List ( Float, Float ) ) -> Cmd msg


port analytics : String -> Cmd msg


port httpError : String -> Cmd msg


port requestFullscreen : () -> Cmd msg
