module Data.Misc exposing (AlbumInAlbum, GPS, KeywordPointer, LocationData, Parent, PhotoInAlbum, ScaledPhoto, albumInAlbumDecoder, gpsDecoder, keywordPointerDecoder, locationDataDecoder, parentDecoder, photoInAlbumDecoder, scaledPhotoDecoder)

import Data.Url as Url exposing (Url)
import Iso8601
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (optional, required)
import Time


type alias PhotoInAlbum =
    { url : Url
    , dateTime : Time.Posix
    , originalImageURL : String
    , scaledPhotos : List ScaledPhoto
    , gps : Maybe GPS
    }


type alias AlbumInAlbum =
    { url : Url
    , name : String
    , scaledPhotos : List ScaledPhoto
    }


type alias ScaledPhoto =
    { url : String
    , maxResolution : Int
    }


type alias GPS =
    { latitude : Float
    , longitude : Float
    , altitude : Float
    }


type alias LocationData =
    { city : String
    , state : String
    , locationCode : String
    , locationName : String
    }


type alias Parent =
    { url : Url
    , name : String
    }


type alias KeywordPointer =
    { url : Url
    , name : String
    }



-- SERIALIZATION --


photoInAlbumDecoder : Decoder PhotoInAlbum
photoInAlbumDecoder =
    Decode.succeed PhotoInAlbum
        |> required "url" Url.urlDecoder
        |> required "dateTime" Iso8601.decoder
        |> required "originalImageURL" Decode.string
        |> required "scaledPhotos" (Decode.list scaledPhotoDecoder)
        |> optional "gps" (Decode.nullable gpsDecoder) Nothing


albumInAlbumDecoder : Decoder AlbumInAlbum
albumInAlbumDecoder =
    Decode.succeed AlbumInAlbum
        |> required "url" Url.urlDecoder
        |> required "name" Decode.string
        |> required "scaledPhotos" (Decode.list scaledPhotoDecoder)


scaledPhotoDecoder : Decoder ScaledPhoto
scaledPhotoDecoder =
    Decode.succeed ScaledPhoto
        |> required "url" Decode.string
        |> required "maxResolution" Decode.int


gpsDecoder : Decoder GPS
gpsDecoder =
    Decode.succeed GPS
        |> required "latitude" Decode.float
        |> required "longitude" Decode.float
        |> required "altitude" Decode.float


locationDataDecoder : Decoder LocationData
locationDataDecoder =
    Decode.succeed LocationData
        |> required "city" Decode.string
        |> required "state" Decode.string
        |> required "locationCode" Decode.string
        |> required "locationName" Decode.string


parentDecoder : Decoder Parent
parentDecoder =
    Decode.succeed Parent
        |> required "url" Url.urlDecoder
        |> required "name" Decode.string


keywordPointerDecoder : Decoder KeywordPointer
keywordPointerDecoder =
    Decode.succeed KeywordPointer
        |> required "url" Url.urlDecoder
        |> required "name" Decode.string



-- IDENTIFIERS --
