module Data.Location exposing (Locations, decoderLocations)

import Data.Misc as Misc
import Json.Decode as Decode exposing (Decoder)


type alias Locations =
    List Misc.PhotoInAlbum


decoderLocations : Decoder Locations
decoderLocations =
    Decode.field "locations" (Decode.list Misc.photoInAlbumDecoder)
