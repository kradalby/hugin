module Data.Photo exposing (Photo, biggest, decoder, thumbnail)

--import Date exposing (Date)
--import Json.Decode.Extra

import Data.Misc exposing (GPS, KeywordPointer, LocationData, Parent, ScaledPhoto, gpsDecoder, keywordPointerDecoder, locationDataDecoder, parentDecoder, scaledPhotoDecoder)
import Data.Url as Url exposing (Url)
import Iso8601
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (optional, required)
import List.Extra
import Time


type alias Photo =
    { shutterSpeed : Maybe Float
    , lensModel : Maybe String
    , people : List KeywordPointer
    , url : Url
    , owner : Maybe String
    , meteringMode : Maybe Int
    , cameraMake : Maybe String
    , isoSpeed : List Int
    , dateTime : Maybe Time.Posix
    , name : String
    , keywords : List KeywordPointer
    , originalImageURL : String
    , modifiedDate : Time.Posix
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
    , location : Maybe LocationData
    , previous : Maybe Url
    , next : Maybe Url
    , parents : List Parent
    }


decoder : Decoder Photo
decoder =
    Decode.succeed Photo
        |> optional "shutterSpeed" (Decode.nullable Decode.float) Nothing
        |> optional "lensModel" (Decode.nullable Decode.string) Nothing
        |> required "people" (Decode.list keywordPointerDecoder)
        |> required "url" Url.urlDecoder
        |> optional "owner" (Decode.nullable Decode.string) Nothing
        |> optional "meteringMode" (Decode.nullable Decode.int) Nothing
        |> optional "cameraMake" (Decode.nullable Decode.string) Nothing
        |> required "isoSpeed" (Decode.list Decode.int)
        |> optional "dateTime" (Decode.nullable Iso8601.decoder) Nothing
        |> required "name" Decode.string
        |> required "keywords" (Decode.list keywordPointerDecoder)
        |> required "originalImageURL" Decode.string
        |> required "modifiedDate" Iso8601.decoder
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
        |> optional "location" (Decode.nullable locationDataDecoder) Nothing
        |> optional "previous" (Decode.nullable Url.urlDecoder) Nothing
        |> optional "next" (Decode.nullable Url.urlDecoder) Nothing
        |> required "parents" (Decode.list parentDecoder)



-- HELPERS --
-- Return image closest to width


thumbnail : List ScaledPhoto -> Int -> String
thumbnail scaledPhotos width =
    let
        distances =
            List.map (\elem -> abs (elem.maxResolution - width)) scaledPhotos

        closest =
            List.minimum distances
                |> Maybe.andThen (\elem -> List.Extra.elemIndex elem distances)
                |> Maybe.andThen (\index -> List.Extra.getAt index scaledPhotos)
    in
    case closest of
        Nothing ->
            ""

        Just photo ->
            photo.url


biggest : List ScaledPhoto -> String
biggest scaledPhotos =
    let
        sp =
            List.sortBy .maxResolution scaledPhotos |> List.reverse
    in
    case List.head sp of
        Nothing ->
            ""

        Just photo ->
            photo.url
