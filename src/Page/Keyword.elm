module Page.Keyword exposing (Model, Msg(..), init, update, view)

{-| Viewing a user's album.
-}

import Data.Keyword as Keyword exposing (Keyword)
import Data.Album as Album exposing (Album)
import Data.Photo as Photo exposing (Photo)
import Data.Url as Url exposing (Url)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Lazy
import Http
import Page.Errored exposing (PageLoadError, pageLoadError)
import Request.Keyword
import Task exposing (Task)
import Util exposing ((=>), pair, viewIf, googleMap, googleMapMarker)
import Views.Errors as Errors
import Views.Page as Page
import Route exposing (Route)


-- MODEL --


type alias Model =
    { errors : List String
    , keyword : Keyword
    }


init : Url -> Task PageLoadError Model
init url =
    let
        loadKeyword =
            Request.Keyword.get url
                |> Http.toTask

        handleLoadError _ =
            "Keyword is currently unavailable."
                |> pageLoadError (Page.Keyword url)
    in
        Task.map (Model []) loadKeyword
            |> Task.mapError handleLoadError



-- VIEW --


view : Model -> Html Msg
view model =
    div [ class "album-page" ]
        [ Errors.view DismissErrors
            model.errors
        , div
            [ class "container-fluid" ]
            [ div [ class "row" ] [ h1 [ class "ml-2" ] [ text model.keyword.name ] ]
            , div [ class "row" ] [ Html.Lazy.lazy viewPhotos model.keyword.photos ]
            , div [ class "row" ] [ viewMap model.keyword.photos ]
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
    let
        markers =
            Debug.log "markers: " <|
                List.filterMap
                    (\photo ->
                        photoMapMarker photo
                    )
                    photos
    in
        div [ class "col-12 col-sm-12 col-md-12 col-lg-12 col-xl-12 p-0" ]
            [ div [ class "mt-3" ]
                (case markers of
                    [] ->
                        []

                    _ ->
                        [ googleMap
                            [ attribute "api-key" "AIzaSyDO4CHjsXnGLSDbrlmG7tOOr3OMcKt4fQI"
                            , attribute "fit-to-markers" ""
                            , attribute "disable-default-ui" "true"
                            , attribute "disable-zoom" "true"
                            ]
                            markers
                        ]
                )
            ]


photoMapMarker : Album.PhotoInAlbum -> Maybe (Html Msg)
photoMapMarker photo =
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


type Msg
    = DismissErrors


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DismissErrors ->
            { model | errors = [] } => Cmd.none
