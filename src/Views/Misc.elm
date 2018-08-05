module Views.Misc exposing (viewKeywords, viewPath, viewPhotos, viewPhoto, viewMap, viewPhotoMapMarker)

{-| Assets, such as images, videos, and audio. (We only have images for now.)

We should never expose asset URLs directly; this module should be in charge of
all of them. One source of truth!

-}

import Html exposing (..)
import Html.Attributes exposing (..)
import Data.Misc exposing (..)
import Data.Url as Url exposing (Url)
import Data.Photo as Photo exposing (Photo)
import Route exposing (Route)
import Util exposing (googleMap, googleMapMarker)


viewKeywords : String -> List KeywordPointer -> Html msg
viewKeywords name keywords =
    let
        links =
            List.intersperse (text ", ") <|
                List.map
                    (\keyword ->
                        a
                            [ class "", Route.href (Route.Keyword (Url.urlToString keyword.url)) ]
                            [ text keyword.name ]
                    )
                    (List.sortBy .name keywords)
    in
        div [ class "col-12 col-sm-12 col-md-6 col-lg-6 col-xl-6" ]
            [ div [ class "mt-3 mb-3" ] <|
                [ h5 [] [ text name ]
                ]
                    ++ links
            ]


viewPath : List Parent -> String -> Html msg
viewPath parents current =
    case parents of
        [] ->
            text ""

        _ ->
            div [ class "col-11 pl-2" ] <|
                List.intersperse
                    --(i [ class "fas fa-angle-right text-white ml-2 mr-2" ] [])
                    (span [ class "text-light ml-2 mr-2" ] [ text ">" ])
                    ((List.map
                        (\parent ->
                            a [ class "text-light", Route.href (Route.Album (Url.urlToString parent.url)) ] [ text parent.name ]
                        )
                        parents
                     )
                        ++ [ span [ class "text-secondary" ] [ text current ] ]
                    )


viewPhotos : List PhotoInAlbum -> Html msg
viewPhotos photos =
    div [ class "flexbin" ] <| List.map viewPhoto (List.sortBy (\photo -> Url.urlToString photo.url) photos)


viewPhoto : PhotoInAlbum -> Html msg
viewPhoto photo =
    a [ Route.href (Route.Photo (Url.urlToString photo.url)) ]
        [ img [ src (Photo.thumbnail photo.scaledPhotos) ] [] ]


viewMap : Bool -> List PhotoInAlbum -> Html msg
viewMap fullScreen photos =
    let
        markers =
            List.filterMap
                (\photo ->
                    viewPhotoMapMarker photo
                )
                photos

        classes =
            case fullScreen of
                False ->
                    ""

                True ->
                    "full-map"
    in
        div [ class "col-12 col-sm-12 col-md-12 col-lg-12 col-xl-12 p-0" ]
            (case markers of
                [] ->
                    []

                _ ->
                    [ googleMap
                        [ attribute "api-key" "AIzaSyDO4CHjsXnGLSDbrlmG7tOOr3OMcKt4fQI"
                        , attribute "fit-to-markers" ""
                        , attribute "disable-default-ui" "true"
                        , attribute "disable-zoom" "true"
                        , class classes
                        ]
                        markers
                    ]
            )


viewPhotoMapMarker : PhotoInAlbum -> Maybe (Html msg)
viewPhotoMapMarker photo =
    Maybe.map
        (\gps ->
            googleMapMarker
                [ attribute "latitude" (toString gps.latitude)
                , attribute "longitude" (toString gps.longitude)
                , attribute "draggable" "false"
                , attribute "slot" "markers"
                ]
                [ img
                    [ src (Photo.thumbnail photo.scaledPhotos)
                    ]
                    []
                ]
        )
        photo.gps
