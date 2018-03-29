module Data.Album exposing (Album, decoder)

import Data.Url as Url exposing (Url)
import Data.Misc as Misc exposing (..)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required, optional)


type alias Album =
    { url : Url
    , photos : List PhotoInAlbum
    , albums : List AlbumInAlbum
    , people : List KeywordPointer
    , keywords : List KeywordPointer
    , name : String
    , parents : List Parent
    }



-- SERIALIZATION --


decoder : Decoder Album
decoder =
    decode Album
        |> required "url" Url.urlDecoder
        |> required "photos" (Decode.list photoInAlbumDecoder)
        |> required "albums" (Decode.list albumInAlbumDecoder)
        |> required "people" (Decode.list keywordPointerDecoder)
        |> required "keywords" (Decode.list keywordPointerDecoder)
        |> required "name" Decode.string
        |> required "parents" (Decode.list parentDecoder)


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



-- IDENTIFIERS --
