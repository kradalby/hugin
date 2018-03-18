module Data.Location exposing (Location, Locations, decoder, decoderLocations)

import Data.Url as Url exposing (Url)
import Data.Photo as Photo exposing (Photo)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required, optional)


type alias Location =
    { url : Url
    , scaledPhotos : List Photo.ScaledPhoto
    , gps : Photo.GPS
    }


type alias Locations =
    { locations : List Location }



-- SERIALIZATION --


decoder : Decoder Location
decoder =
    decode Location
        |> required "url" Url.urlDecoder
        |> required "scaledPhotos" (Decode.list Photo.scaledPhotoDecoder)
        |> required "gps" Photo.gpsDecoder


decoderLocations : Decoder Locations
decoderLocations =
    decode Locations
        |> required "locations" (Decode.list decoder)
