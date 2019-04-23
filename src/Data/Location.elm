module Data.Location exposing (Locations, decoderLocations)

import Data.Misc exposing (PhotoInAlbum, photoInAlbumDecoder)
import Json.Decode as Decode exposing (Decoder)


type alias Locations =
    List PhotoInAlbum


decoderLocations : Decoder Locations
decoderLocations =
    Decode.field "locations" (Decode.list photoInAlbumDecoder)
