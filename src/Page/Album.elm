module Page.Album exposing (Model, Msg(..), init, update, view)

{-| Viewing a user's album.
-}

import Data.Album as Album exposing (Album)
import Data.Photo as Photo exposing (Photo)
import Data.Url as Url exposing (Url)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Lazy
import Http
import Page.Errored exposing (PageLoadError, pageLoadError)
import Request.Album
import Task exposing (Task)
import Util exposing ((=>), pair, viewIf, googleMap, googleMapMarker)
import Views.Errors as Errors
import Views.Assets as Assets
import Views.Page as Page
import Views.Misc exposing (viewKeywords, viewPath)
import Route exposing (Route)


-- MODEL --


type alias Model =
    { errors : List String
    , album : Album
    }


init : Url -> Task PageLoadError Model
init url =
    let
        loadAlbum =
            Request.Album.get url
                |> Http.toTask

        handleLoadError _ =
            "Album is currently unavailable."
                |> pageLoadError (Page.Album url)
    in
        Task.map (Model []) loadAlbum
            |> Task.mapError handleLoadError



-- VIEW --


view : Model -> Html Msg
view model =
    let
        album =
            model.album
    in
        div [ class "album-page" ]
            [ Errors.view DismissErrors
                model.errors
            , div
                [ class "container-fluid" ]
                [ div [ class "row" ] [ viewPath album.parents ]
                , div [ class "row" ]
                    [ Html.Lazy.lazy viewNestedAlbums album.albums ]
                , div [ class "row" ] [ Html.Lazy.lazy viewPhotos album.photos ]
                , div [ class "row" ]
                    [ Html.Lazy.lazy2 viewKeywords
                        "People"
                        album.people
                    , Html.Lazy.lazy2 viewKeywords
                        "Tags"
                        album.keywords
                    ]
                , div [ class "row" ] [ viewMap album.photos ]
                ]
            ]


viewNestedAlbums : List Album.AlbumInAlbum -> Html Msg
viewNestedAlbums albums =
    case albums of
        [] ->
            text ""

        _ ->
            div [ class "col-12 col-sm-12 col-md-12 col-lg-12 col-xl-12 p-0 mt-3 mb-5" ]
                [ div [ class "row justify-content-center" ] <|
                    List.map viewNestedAlbum (List.sortBy .name albums)
                ]


viewNestedAlbum : Album.AlbumInAlbum -> Html Msg
viewNestedAlbum album =
    div [ class "col-12 col-sm-6 col-md-4 col-lg-4 col-xl-3" ]
        [ div [ class "image-album-container" ]
            [ a [ class "", Route.href (Route.Album (Url.urlToString album.url)) ]
                [ (case album.scaledPhotos of
                    [] ->
                        img [ Assets.src Assets.placeholder, alt "Placeholder image", width 300 ] []

                    _ ->
                        img [ src (Photo.thumbnail album.scaledPhotos) ] []
                  )
                , h3 [] [ text album.name ]
                ]
            ]
        ]


viewPhotos : List Album.PhotoInAlbum -> Html Msg
viewPhotos photos =
    div [ class "flexbin" ] <| List.map viewPhoto (List.sortBy (\photo -> Url.urlToString photo.url) photos)


viewPhoto : Album.PhotoInAlbum -> Html Msg
viewPhoto photo =
    a [ Route.href (Route.Photo (Url.urlToString photo.url)) ]
        [ img [ src (Photo.thumbnail photo.scaledPhotos) ] [] ]


viewMap : List Album.PhotoInAlbum -> Html Msg
viewMap photos =
    div [ class "col-12 col-sm-12 col-md-12 col-lg-12 col-xl-12 p-0" ]
        [ div [ class "mt-3" ]
            (case photos of
                [] ->
                    []

                locations ->
                    [ googleMap
                        [ attribute "api-key" "AIzaSyDO4CHjsXnGLSDbrlmG7tOOr3OMcKt4fQI"
                        , attribute "fit-to-markers" ""
                        , attribute "disable-default-ui" "true"
                        , attribute "disable-zoom" "true"
                        ]
                      <|
                        List.map
                            (\photo ->
                                photoMapMarker photo
                            )
                            locations
                    ]
            )
        ]


photoMapMarker : Album.PhotoInAlbum -> Html Msg
photoMapMarker photo =
    case photo.gps of
        Nothing ->
            text ""

        Just gps ->
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


type Msg
    = DismissErrors


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        album =
            model.album
    in
        case msg of
            DismissErrors ->
                { model | errors = [] } => Cmd.none
