module Data.Stats exposing (Stats, Statss, decoder)

import Data.Photo as Photo exposing (Photo)
import Data.Url as Url exposing (Url)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (required)


type alias Stats =
    { writtenPhotos : Int
    , albums : Int
    , originalPhotos : Int
    , keywords : Int
    , people : Int
    }


type alias Statss =
    { locations : List Stats }



-- SERIALIZATION --


decoder : Decoder Stats
decoder =
    Decode.succeed Stats
        |> required "writtenPhotos" Decode.int
        |> required "albums" Decode.int
        |> required "originalPhotos" Decode.int
        |> required "keywords" Decode.int
        |> required "people" Decode.int
