port module Ports exposing (analytics, downloadImages, initMap)


port downloadImages : List String -> Cmd msg


port initMap : ( String, List ( Float, Float ) ) -> Cmd msg


port analytics : String -> Cmd msg
