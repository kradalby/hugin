module Data.Photo exposing (Photo, GPS, thumbnail, decoder)

import Data.Url as Url exposing (Url)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required, optional)
import List.Extra
import Random
import Random.List


type alias Photo =
    { shutterSpeed : Maybe Float
    , lensModel : Maybe String
    , people : List String
    , url : Url
    , owner : String
    , meteringMode : Maybe Int
    , cameraMake : Maybe String
    , isoSpeed : List Int
    , dateTime : String
    , name : String
    , keywords : List String
    , originalImageURL : String
    , modifiedDate : String
    , fNumber : Maybe Float
    , height : Int
    , width : Int
    , scaledPhotos : List ScaledPhoto
    , aperture : Maybe Float
    , copyright : String
    , cameraModel : Maybe String
    , focalLength : Maybe Float
    , gps : Maybe GPS
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


decoder : Decoder Photo
decoder =
    decode Photo
        |> required "shutterSpeed" (Decode.nullable Decode.float)
        |> required "lensModel" (Decode.nullable Decode.string)
        |> required "people" (Decode.list Decode.string)
        |> required "url" Url.urlDecoder
        |> required "owner" Decode.string
        |> required "meteringMode" (Decode.nullable Decode.int)
        |> required "cameraMake" (Decode.nullable Decode.string)
        |> required "isoSpeed" (Decode.list Decode.int)
        |> required "dateTime" Decode.string
        |> required "name" Decode.string
        |> required "keywords" (Decode.list Decode.string)
        |> required "originalImageURL" Decode.string
        |> required "modifiedDate" Decode.string
        |> required "fNumber" (Decode.nullable Decode.float)
        |> required "height" Decode.int
        |> required "width" Decode.int
        |> required "scaledPhotos" (Decode.list scaledPhotoDecoder)
        |> required "aperture" (Decode.nullable Decode.float)
        |> required "copyright" Decode.string
        |> required "cameraModel" (Decode.nullable Decode.string)
        |> required "focalLength" (Decode.nullable Decode.float)
        |> required "gps" (Decode.nullable gpsDecoder)


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



-- HELPERS --


thumbnail : Photo -> String
thumbnail photo =
    case (List.Extra.last photo.scaledPhotos) of
        Nothing ->
            ""

        Just thumb ->
            thumb.url
