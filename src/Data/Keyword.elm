module Data.Keyword exposing (Keyword, decoder)

import Data.Misc exposing (PhotoInAlbum, photoInAlbumDecoder)
import Data.Url as Url exposing (Url)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (required)


type alias Keyword =
    { url : Url
    , photos : List PhotoInAlbum
    , name : String
    }


decoder : Decoder Keyword
decoder =
    Decode.succeed Keyword
        |> required "url" Url.urlDecoder
        |> required "photos" (Decode.list photoInAlbumDecoder)
        |> required "name" Decode.string



-- IDENTIFIERS --
