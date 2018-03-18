module Data.Album exposing (Album, PhotoInAlbum, AlbumInAlbum, decoder)

import Data.Url as Url exposing (Url)
import Data.Photo as Photo exposing (Photo)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required, optional)


type alias Album =
    { url : Url
    , photos : List PhotoInAlbum
    , albums : List AlbumInAlbum
    , people : List String
    , keywords : List String
    , name : String
    }


type alias PhotoInAlbum =
    { url : Url
    , scaledPhotos : List Photo.ScaledPhoto
    , gps : Maybe Photo.GPS
    }


type alias AlbumInAlbum =
    { url : Url
    , name : String
    , scaledPhotos : List Photo.ScaledPhoto
    }



-- SERIALIZATION --


decoder : Decoder Album
decoder =
    decode Album
        |> required "url" Url.urlDecoder
        |> required "photos" (Decode.list photoInAlbumDecoder)
        |> required "albums" (Decode.list albumInAlbumDecoder)
        |> required "people" (Decode.list Decode.string)
        |> required "keywords" (Decode.list Decode.string)
        |> required "name" Decode.string


photoInAlbumDecoder : Decoder PhotoInAlbum
photoInAlbumDecoder =
    decode PhotoInAlbum
        |> required "url" Url.urlDecoder
        |> required "scaledPhotos" (Decode.list Photo.scaledPhotoDecoder)
        |> optional "gps" (Decode.nullable Photo.gpsDecoder) Nothing


albumInAlbumDecoder : Decoder AlbumInAlbum
albumInAlbumDecoder =
    decode AlbumInAlbum
        |> required "url" Url.urlDecoder
        |> required "name" Decode.string
        |> required "scaledPhotos" (Decode.list Photo.scaledPhotoDecoder)



-- IDENTIFIERS --
