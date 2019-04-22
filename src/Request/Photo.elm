module Request.Photo exposing (get)

import Data.Photo as Photo exposing (Photo)
import Data.Url as Url exposing (Url)
import Http



-- GET --


get : Url -> (Result Http.Error Photo -> msg) -> Cmd msg
get url msg =
    Http.get
        { expect = Http.expectJson msg Photo.decoder
        , url = Url.urlToString url
        }
