module Request.Photo exposing (get)

import Data.Photo as Photo exposing (Photo)
import Data.Url as Url exposing (Url)
import Http
import HttpBuilder exposing (RequestBuilder)
import Request.Helpers exposing (apiUrl)



-- GET --


get : Url -> Http.Request Photo
get url =
    apiUrl (Url.urlToString url)
        |> HttpBuilder.get
        |> HttpBuilder.withExpect (Http.expectJson Photo.decoder)
        |> HttpBuilder.toRequest
