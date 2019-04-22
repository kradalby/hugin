module Request.Album exposing (get)

import Data.Album as Album exposing (Album)
import Data.Url as Url exposing (Url)
import Http
import HttpBuilder exposing (RequestBuilder)
import Request.Helpers exposing (apiUrl)



-- GET --


get : Url -> Http.Request Album
get url =
    apiUrl (Url.urlToString url)
        |> HttpBuilder.get
        |> HttpBuilder.withExpect (Http.expectJson Album.decoder)
        |> HttpBuilder.toRequest
