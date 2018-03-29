module Data.Keyword exposing (Keyword, decoder)

import Data.Url as Url exposing (Url)
import Data.Photo as Photo exposing (Photo)
import Data.Album as Album exposing (Album)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required, optional)


type alias Keyword =
    { url : Url
    , photos : List Album.PhotoInAlbum
    , name : String
    }


decoder : Decoder Keyword
decoder =
    decode Keyword
        |> required "url" Url.urlDecoder
        |> required "photos" (Decode.list Album.photoInAlbumDecoder)
        |> required "name" Decode.string



-- IDENTIFIERS --
