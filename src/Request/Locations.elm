module Request.Locations exposing (get)

import Data.Location as Location exposing (Locations)
import Data.Url as Url exposing (Url)
import Http
import Request.Helpers exposing (apiUrl)



-- GET --


get : Url -> (Result Http.Error Locations -> msg) -> Cmd msg
get url msg =
    Http.get
        { expect = Http.expectJson msg Location.decoderLocations
        , url = Url.urlToString url
        }
