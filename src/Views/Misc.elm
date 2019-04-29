module Views.Misc exposing (loading, scaledImg, scaledImgCount, viewKeywords, viewMap, viewPath, viewPhoto, viewPhotos)

{-| Assets, such as images, videos, and audio. (We only have images for now.)

We should never expose asset URLs directly; this module should be in charge of
all of them. One source of truth!

-}

import Data.Misc exposing (KeywordPointer, Parent, PhotoInAlbum)
import Data.Photo as Photo exposing (Photo)
import Data.Url as Url
import Html exposing (Html, a, div, h5, img, span, text)
import Html.Attributes exposing (attribute, class, id, src)
import Route


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
                    keywords
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
            div [ class "col-10 pl-2" ] <|
                List.intersperse
                    --(i [ class "fas fa-angle-right text-white ml-2 mr-2" ] [])
                    (span [ class "text-light ml-2 mr-2" ] [ text ">" ])
                    (List.map
                        (\parent ->
                            a [ class "text-light", Route.href (Route.Album (Url.urlToString parent.url)) ] [ text parent.name ]
                        )
                        parents
                        ++ [ span [ class "text-secondary" ] [ text current ] ]
                    )


scaledImgCount : Int -> List Data.Misc.ScaledPhoto -> Int -> Html msg
scaledImgCount widthFactor scaledPhotos count =
    let
        sp =
            List.sortBy .maxResolution scaledPhotos |> List.take count

        srcset =
            List.map
                (\scaledPhoto ->
                    scaledPhoto.url ++ " " ++ String.fromInt (scaledPhoto.maxResolution * widthFactor) ++ "w"
                )
                sp
                |> String.join ", "

        sizes =
            List.map
                (\scaledPhoto ->
                    "(max-width: "
                        ++ String.fromInt (scaledPhoto.maxResolution * widthFactor)
                        ++ "px)"
                        ++ " "
                        ++ String.fromInt scaledPhoto.maxResolution
                        ++ "px"
                )
                sp
                |> String.join ", "
    in
    img
        [ class "mx-auto d-block img-fluid"
        , attribute "sizes" sizes
        , attribute "srcset" srcset
        , src <| Photo.biggest sp
        , loading "lazy"
        ]
        []


scaledImg : List Data.Misc.ScaledPhoto -> Html msg
scaledImg scaledPhotos =
    scaledImgCount 1 scaledPhotos (List.length scaledPhotos)


viewPhotos : List PhotoInAlbum -> Html msg
viewPhotos photos =
    div [ class "flexbin" ] <| List.map viewPhoto (List.sortBy (\photo -> Url.urlToString photo.url) photos)


viewPhoto : PhotoInAlbum -> Html msg
viewPhoto photo =
    a [ Route.href (Route.Photo (Url.urlToString photo.url)) ]
        [ scaledImgCount 2 photo.scaledPhotos 3 ]


viewMap : String -> Int -> Int -> Int -> Int -> Int -> Html msg
viewMap name col sm md lg xl =
    let
        cls =
            String.join " "
                [ "col-" ++ String.fromInt col
                , "col-sm-" ++ String.fromInt sm
                , "col-md-" ++ String.fromInt md
                , "col-lg-" ++ String.fromInt lg
                , "col-xl-" ++ String.fromInt xl
                ]
    in
    div [ class <| "p-0 " ++ cls ]
        [ div [ id <| "map-" ++ name, class "map" ] []
        ]


loading : String -> Html.Attribute msg
loading value =
    attribute "loading" value
