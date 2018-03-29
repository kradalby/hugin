module Page.Keyword exposing (Model, Msg(..), init, update, view)

{-| Viewing a user's album.
-}

import Data.Keyword as Keyword exposing (Keyword)
import Data.Album as Album exposing (Album)
import Data.Photo as Photo exposing (Photo)
import Data.Misc exposing (..)
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
import Views.Misc exposing (viewPhotos, viewPhoto, viewMap, viewPhotoMapMarker)


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


type Msg
    = DismissErrors


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DismissErrors ->
            { model | errors = [] } => Cmd.none
