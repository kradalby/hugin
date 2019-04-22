module Request.Keyword exposing (get)

import Data.Keyword as Keyword exposing (Keyword)
import Data.Url as Url exposing (Url)
import Http



-- GET --


get : Url -> (Result Http.Error Keyword -> msg) -> Cmd msg
get url msg =
    Http.get
        { expect = Http.expectJson msg Keyword.decoder
        , url = Url.urlToString url
        }
