module Data.Album exposing (Album, decoder)

import Data.Misc exposing (..)
import Data.Url as Url exposing (Url)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (required)


type alias Album =
    { url : Url
    , photos : List PhotoInAlbum
    , albums : List AlbumInAlbum
    , people : List KeywordPointer
    , keywords : List KeywordPointer
    , name : String
    , parents : List Parent
    }



-- SERIALIZATION --


decoder : Decoder Album
decoder =
    Decode.succeed Album
        |> required "url" Url.urlDecoder
        |> required "photos" (Decode.list photoInAlbumDecoder)
        |> required "albums" (Decode.list albumInAlbumDecoder)
        |> required "people" (Decode.list keywordPointerDecoder)
        |> required "keywords" (Decode.list keywordPointerDecoder)
        |> required "name" Decode.string
        |> required "parents" (Decode.list parentDecoder)



-- IDENTIFIERS --
