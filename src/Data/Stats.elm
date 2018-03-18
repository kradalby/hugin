module Data.Stats exposing (Stats, Statss, decoder)

import Data.Url as Url exposing (Url)
import Data.Photo as Photo exposing (Photo)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required, optional)


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
    decode Stats
        |> required "writtenPhotos" Decode.int
        |> required "albums" Decode.int
        |> required "originalPhotos" Decode.int
        |> required "keywords" Decode.int
        |> required "people" Decode.int
