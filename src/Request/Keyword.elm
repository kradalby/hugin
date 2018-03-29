module Request.Keyword exposing (get)

import Data.Keyword as Keyword exposing (Keyword)
import Data.Url as Url exposing (Url)
import Http
import HttpBuilder exposing (RequestBuilder, withExpect, withQueryParams)
import Request.Helpers exposing (apiUrl)
import Util


-- GET --


get : Url -> Http.Request Keyword
get url =
    apiUrl (Url.urlToString url)
        |> HttpBuilder.get
        |> HttpBuilder.withExpect (Http.expectJson (Util.traceDecoder "Keyword: " Keyword.decoder))
        |> HttpBuilder.toRequest
