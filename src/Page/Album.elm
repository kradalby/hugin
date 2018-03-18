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
import Views.Page as Page
import Views.Misc exposing (viewKeywords)
import Route exposing (Route)


-- MODEL --


type alias Model =
    { errors : List String
    , album : Album
    , nestedAlbums : List Album
    }


init : Url -> Task PageLoadError Model
init url =
    let
        loadAlbum =
            Request.Album.get url
                |> Http.toTask

        loadNestedAlbums =
            loadAlbum
                |> Task.andThen
                    (\album ->
                        Task.sequence (List.map (\url -> Request.Album.get url |> Http.toTask) album.albums)
                    )

        handleLoadError _ =
            "Album is currently unavailable."
                |> pageLoadError (Page.Album url)
    in
        Task.map2 (Model []) loadAlbum loadNestedAlbums
            |> Task.mapError handleLoadError



-- VIEW --


view : Model -> Html Msg
view model =
    let
        album =
            model.album

        nestedAlbums =
            model.nestedAlbums
    in
        div [ class "album-page" ]
            [ Errors.view DismissErrors
                model.errors
            , div
                [ class "container-fluid" ]
                [ div [ class "row" ]
                    [ Html.Lazy.lazy viewNestedAlbums nestedAlbums ]
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


viewNestedAlbums : List Album -> Html Msg
viewNestedAlbums albums =
    case albums of
        [] ->
            text ""

        _ ->
            div [ class "col-12 col-sm-12 col-md-12 col-lg-12 col-xl-12 mt-3" ]
                [ ul [ class "nav nav-fill" ] <|
                    List.map viewNestedAlbum albums
                ]


viewNestedAlbum : Album -> Html Msg
viewNestedAlbum album =
    if album.photos /= [] || album.albums /= [] then
        li [ class "nav-item" ]
            [ a [ class "nav-link", Route.href (Route.Album (Url.urlToString album.url)) ]
                [ h3 [] [ text album.name ] ]
            ]
    else
        text ""


viewPhotos : List Album.PhotoInAlbum -> Html Msg
viewPhotos photos =
    div [ class "flexbin" ] <| List.map viewPhoto photos


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
    | AlbumLoaded (Result Http.Error Album)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        album =
            model.album
    in
        case msg of
            DismissErrors ->
                { model | errors = [] } => Cmd.none

            AlbumLoaded (Ok response) ->
                ( { model
                    | nestedAlbums = response :: model.nestedAlbums
                  }
                , Cmd.none
                )

            AlbumLoaded (Err _) ->
                ( model
                , Cmd.none
                )
