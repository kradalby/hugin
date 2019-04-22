module Request.Locations exposing (get)

import Data.Location as Location exposing (Locations)
import Data.Url as Url exposing (Url)
import Http
import HttpBuilder exposing (RequestBuilder)
import Request.Helpers exposing (apiUrl)



-- GET --


get : Url -> Http.Request Locations
get url =
    apiUrl (Url.urlToString url)
        |> HttpBuilder.get
        |> HttpBuilder.withExpect (Http.expectJson Location.decoderLocations)
        |> HttpBuilder.toRequest
