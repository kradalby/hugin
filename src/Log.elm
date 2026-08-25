module Log exposing (httpError)

import Http
import Ports


httpError : Http.Error -> Cmd msg
httpError err =
    let
        value =
            case err of
                Http.BadUrl url ->
                    "Bad URL: " ++ url

                Http.Timeout ->
                    "Timeout"

                Http.NetworkError ->
                    "NetworkError"

                Http.BadStatus status ->
                    "Bad Status: " ++ String.fromInt status

                Http.BadBody body ->
                    "Bad Body: " ++ body
    in
    Ports.httpError value
