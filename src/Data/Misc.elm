module Data.Misc exposing (..)

import Data.Url as Url exposing (Url)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required, optional)


type alias PhotoInAlbum =
    { url : Url
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
    decode PhotoInAlbum
        |> required "url" Url.urlDecoder
        |> required "scaledPhotos" (Decode.list scaledPhotoDecoder)
        |> optional "gps" (Decode.nullable gpsDecoder) Nothing


albumInAlbumDecoder : Decoder AlbumInAlbum
albumInAlbumDecoder =
    decode AlbumInAlbum
        |> required "url" Url.urlDecoder
        |> required "name" Decode.string
        |> required "scaledPhotos" (Decode.list scaledPhotoDecoder)


scaledPhotoDecoder : Decoder ScaledPhoto
scaledPhotoDecoder =
    decode ScaledPhoto
        |> required "url" Decode.string
        |> required "maxResolution" Decode.int


gpsDecoder : Decoder GPS
gpsDecoder =
    decode GPS
        |> required "latitude" Decode.float
        |> required "longitude" Decode.float
        |> required "altitude" Decode.float


parentDecoder : Decoder Parent
parentDecoder =
    decode Parent
        |> required "url" Url.urlDecoder
        |> required "name" Decode.string


keywordPointerDecoder : Decoder KeywordPointer
keywordPointerDecoder =
    decode KeywordPointer
        |> required "url" Url.urlDecoder
        |> required "name" Decode.string



-- IDENTIFIERS --
