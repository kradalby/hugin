module Page.Album exposing (Model, Msg(..), init, update, view)

{-| Viewing a user's album.
-}

import Data.Album as Album exposing (Album)
import Data.Photo as Photo exposing (Photo)
import Data.Misc exposing (..)
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
import Views.Misc exposing (viewKeywords, viewPath, viewPhotos, viewPhoto, viewMap, viewPhotoMapMarker)
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
                [ div [ class "row bg-darklight" ] [ viewPath album.parents album.name ]
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


viewNestedAlbums : List AlbumInAlbum -> Html Msg
viewNestedAlbums albums =
    case albums of
        [] ->
            text ""

        _ ->
            div [ class "col-12 col-sm-12 col-md-12 col-lg-12 col-xl-12 p-0 mb-5" ]
                [ div [ class "row m-0" ] <|
                    List.map viewNestedAlbum (List.sortBy .name albums)
                ]


viewNestedAlbum : AlbumInAlbum -> Html Msg
viewNestedAlbum album =
    div [ class "col-12 col-sm-6 col-md-6 col-lg-4 col-xl-3 mt-3 d-flex justify-content-around" ]
        [ div [ class "image-album-container" ]
            [ a [ class "", Route.href (Route.Album (Url.urlToString album.url)) ]
                [ (case album.scaledPhotos of
                    [] ->
                        img [ Assets.src Assets.placeholder, alt "Placeholder image", width 300 ] []

                    _ ->
                        img [ src (Photo.thumbnail album.scaledPhotos) ] []
                  )
                , h4 [] [ text album.name ]
                ]
            ]
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
