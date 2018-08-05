module Page.Album exposing (Model, Msg(..), init, update, view, subscriptions)

{-| Viewing a user's album.
-}

import Data.Album as Album exposing (Album)
import Data.Photo as Photo exposing (Photo)
import Data.Misc exposing (..)
import Data.Url as Url exposing (Url)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Lazy
import Http
import Page.Errored exposing (PageLoadError, pageLoadError)
import Request.Album
import Task exposing (Task)
import Util exposing ((=>), pair, viewIf)
import Views.Errors as Errors
import Views.Assets as Assets
import Views.Page as Page
import Views.Misc exposing (viewKeywords, viewPath, viewPhotos, viewPhoto, viewMap)
import Route exposing (Route)
import Ports
import Json.Decode as Decode


-- MODEL --


type alias Model =
    { errors : List String
    , showDownloadModal : Bool
    , downloadProgress : Float
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
        Task.map (Model [] False 0.0) loadAlbum
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
                [ div [ class "row bg-darklight" ] [ viewPath album.parents album.name, viewDownloadButton ]
                , viewIf model.showDownloadModal (viewDownloadModal model)
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
                , div [ class "row" ] [ viewMap ]
                ]
            ]


viewDownloadButton : Html Msg
viewDownloadButton =
    div [ class "ml-auto mr-2" ] [ a [ onClick ToggleDownloadModal ] [ i [ class "fas fa-download text-white" ] [] ] ]


viewDownloadModal : Model -> Html Msg
viewDownloadModal model =
    div [ style [ ( "display", "block" ) ], attribute "aria-hidden" "false", attribute "aria-labelledby" "downloadModal", class "modal", id "downloadModal", attribute "role" "dialog", attribute "tabindex" "-1" ]
        [ div [ class "modal-dialog modal-dialog-centered", attribute "role" "document" ]
            [ div [ class "modal-content" ]
                [ div [ class "modal-header" ]
                    [ h5 [ class "modal-title", id "downloadModalTitle" ]
                        [ text "Download album" ]
                    , button [ onClick ToggleDownloadModal, attribute "aria-label" "Close", class "close", attribute "data-dismiss" "modal", type_ "button" ]
                        [ span [ attribute "aria-hidden" "true" ]
                            [ text "×" ]
                        ]
                    ]
                , div [ class "modal-body" ]
                    [ text "This feature is experimental, and will probably at best crash your browser."
                    , hr [] []
                    , div
                        [ class "progress" ]
                        [ div
                            [ attribute "aria-valuemax" "100"
                            , attribute "aria-valuemin" "0"
                            , attribute "aria-valuenow" (toString model.downloadProgress)
                            , class "progress-bar"
                            , attribute "role" "progressbar"
                            , attribute "style"
                                ("width:"
                                    ++ (toString model.downloadProgress)
                                    ++ "%;"
                                )
                            ]
                            [ text <| (toString model.downloadProgress) ++ "%" ]
                        ]
                    ]
                , div [ class "modal-footer" ]
                    [ button [ onClick ToggleDownloadModal, class "btn btn-secondary", attribute "data-dismiss" "modal", type_ "button" ]
                        [ text "Close" ]
                    , button [ onClick Download, class "btn btn-primary", type_ "button" ]
                        [ text "Download" ]
                    ]
                ]
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
    | ToggleDownloadModal
    | Download
    | OnDownloadProgressUpdate (Maybe Float)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        album =
            model.album
    in
        case msg of
            DismissErrors ->
                { model | errors = [] } => Cmd.none

            ToggleDownloadModal ->
                { model
                    | showDownloadModal = not model.showDownloadModal
                    , downloadProgress = 0.0
                }
                    => Cmd.none

            Download ->
                let
                    urls =
                        List.map
                            .originalImageURL
                            album.photos
                in
                    { model | downloadProgress = 0.0 } => Ports.downloadImages urls

            OnDownloadProgressUpdate (Just progress) ->
                { model | downloadProgress = progress } => Cmd.none

            OnDownloadProgressUpdate Nothing ->
                model => Cmd.none


onDownloadProgressUpdate : Sub (Maybe Float)
onDownloadProgressUpdate =
    Ports.downloadProgress (Decode.decodeValue Decode.float >> Result.toMaybe)


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map OnDownloadProgressUpdate onDownloadProgressUpdate
