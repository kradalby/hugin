module Data.Album exposing (Album, decoder)

import Data.Url as Url exposing (Url)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required)


type alias Album =
    { url : Url
    , photos : List Url
    , albums : List Url
    , people : List String
    , keywords : List String
    , name : String
    }



-- SERIALIZATION --


decoder : Decoder Album
decoder =
    decode Album
        |> required "url" Url.urlDecoder
        |> required "photos" (Decode.list Url.urlDecoder)
        |> required "albums" (Decode.list Url.urlDecoder)
        |> required "people" (Decode.list Decode.string)
        |> required "keywords" (Decode.list Decode.string)
        |> required "name" Decode.string



-- IDENTIFIERS --
