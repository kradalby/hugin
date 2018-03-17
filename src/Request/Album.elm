module Request.Album exposing (get)

import Data.Album as Album exposing (Album)
import Data.Url as Url exposing (Url)
import Http
import HttpBuilder exposing (RequestBuilder, withExpect, withQueryParams)
import Request.Helpers exposing (apiUrl)
import Util


-- GET --


get : Url -> Http.Request Album
get url =
    apiUrl (Url.urlToString url)
        |> HttpBuilder.get
        |> HttpBuilder.withExpect (Http.expectJson (Util.traceDecoder "Album: " Album.decoder))
        |> HttpBuilder.toRequest
