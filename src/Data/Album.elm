module Data.Album exposing (Album, PhotoInAlbum, decoder)

import Data.Url as Url exposing (Url)
import Data.Photo as Photo exposing (Photo)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required, optional)


type alias Album =
    { url : Url
    , photos : List PhotoInAlbum
    , albums : List Url
    , people : List String
    , keywords : List String
    , name : String
    }


type alias PhotoInAlbum =
    { url : Url
    , scaledPhotos : List Photo.ScaledPhoto
    , gps : Maybe Photo.GPS
    }



-- SERIALIZATION --


decoder : Decoder Album
decoder =
    decode Album
        |> required "url" Url.urlDecoder
        |> required "photos" (Decode.list photoInAlbumDecoder)
        |> required "albums" (Decode.list Url.urlDecoder)
        |> required "people" (Decode.list Decode.string)
        |> required "keywords" (Decode.list Decode.string)
        |> required "name" Decode.string


photoInAlbumDecoder : Decoder PhotoInAlbum
photoInAlbumDecoder =
    decode PhotoInAlbum
        |> required "url" Url.urlDecoder
        |> required "scaledPhotos" (Decode.list Photo.scaledPhotoDecoder)
        |> optional "gps" (Decode.nullable Photo.gpsDecoder) Nothing



-- IDENTIFIERS --
