port module Ports exposing (analytics, downloadImages, httpError, initMap)


port downloadImages : List String -> Cmd msg


port initMap : ( String, List ( Float, Float ) ) -> Cmd msg


port analytics : String -> Cmd msg


port httpError : String -> Cmd msg
