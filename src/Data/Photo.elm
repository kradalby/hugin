module Data.Photo exposing (Photo, GPS, ScaledPhoto, scaledPhotoDecoder, gpsDecoder, thumbnail, decoder, Parent, parentDecoder)

import Data.Url as Url exposing (Url)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required, optional)
import Json.Decode.Extra
import List.Extra
import Date exposing (Date)


type alias Photo =
    { shutterSpeed : Maybe Float
    , lensModel : Maybe String
    , people : List String
    , url : Url
    , owner : Maybe String
    , meteringMode : Maybe Int
    , cameraMake : Maybe String
    , isoSpeed : List Int
    , dateTime : Maybe Date
    , name : String
    , keywords : List String
    , originalImageURL : String
    , modifiedDate : String
    , fNumber : Maybe Float
    , height : Maybe Int
    , width : Maybe Int
    , scaledPhotos : List ScaledPhoto
    , aperture : Maybe Float
    , copyright : Maybe String
    , cameraModel : Maybe String
    , focalLength : Maybe Float
    , exposureTime : Maybe Float
    , gps : Maybe GPS
    , previous : Maybe Url
    , next : Maybe Url
    , parents : List Parent
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


decoder : Decoder Photo
decoder =
    decode Photo
        |> optional "shutterSpeed" (Decode.nullable Decode.float) Nothing
        |> optional "lensModel" (Decode.nullable Decode.string) Nothing
        |> required "people" (Decode.list Decode.string)
        |> required "url" Url.urlDecoder
        |> optional "owner" (Decode.nullable Decode.string) Nothing
        |> optional "meteringMode" (Decode.nullable Decode.int) Nothing
        |> optional "cameraMake" (Decode.nullable Decode.string) Nothing
        |> required "isoSpeed" (Decode.list Decode.int)
        |> optional "dateTime" (Decode.nullable Json.Decode.Extra.date) Nothing
        |> required "name" Decode.string
        |> required "keywords" (Decode.list Decode.string)
        |> required "originalImageURL" Decode.string
        |> required "modifiedDate" Decode.string
        |> optional "fNumber" (Decode.nullable Decode.float) Nothing
        |> optional "height" (Decode.nullable Decode.int) Nothing
        |> optional "width" (Decode.nullable Decode.int) Nothing
        |> required "scaledPhotos" (Decode.list scaledPhotoDecoder)
        |> optional "aperture" (Decode.nullable Decode.float) Nothing
        |> optional "copyright" (Decode.nullable Decode.string) Nothing
        |> optional "cameraModel" (Decode.nullable Decode.string) Nothing
        |> optional "focalLength" (Decode.nullable Decode.float) Nothing
        |> optional "exposureTime" (Decode.nullable Decode.float) Nothing
        |> optional "gps" (Decode.nullable gpsDecoder) Nothing
        |> optional "previous" (Decode.nullable Url.urlDecoder) Nothing
        |> optional "next" (Decode.nullable Url.urlDecoder) Nothing
        |> required "parents" (Decode.list parentDecoder)


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



-- HELPERS --


thumbnail : List ScaledPhoto -> String
thumbnail scaledPhotos =
    case (List.Extra.last scaledPhotos) of
        Nothing ->
            ""

        Just thumb ->
            thumb.url
