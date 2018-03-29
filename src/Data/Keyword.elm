module Data.Keyword exposing (Keyword, decoder)

import Data.Url as Url exposing (Url)
import Data.Misc exposing (..)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required, optional)


type alias Keyword =
    { url : Url
    , photos : List PhotoInAlbum
    , name : String
    }


decoder : Decoder Keyword
decoder =
    decode Keyword
        |> required "url" Url.urlDecoder
        |> required "photos" (Decode.list photoInAlbumDecoder)
        |> required "name" Decode.string



-- IDENTIFIERS --
