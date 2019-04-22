module Request.Album exposing (get)

import Data.Album as Album exposing (Album)
import Data.Url as Url exposing (Url)
import Http
import Request.Helpers exposing (apiUrl)



-- GET --


get : Url -> (Result Http.Error Album -> msg) -> Cmd msg
get url msg =
    Http.get
        { expect = Http.expectJson msg Album.decoder
        , url = Url.urlToString url
        }
