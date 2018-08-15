module Page.Keyword exposing (Model, Msg(..), init, update, view, initMap)

{-| Viewing a user's album.
-}

import Data.Keyword as Keyword exposing (Keyword)
import Data.Url as Url exposing (Url)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Lazy
import Http
import Page.Errored exposing (PageLoadError, pageLoadError)
import Request.Keyword
import Task exposing (Task)
import Util exposing ((=>), pair, viewIf)
import Views.Errors as Errors
import Views.Page as Page
import Views.Misc exposing (viewPhotos, viewPhoto, viewMap)


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

        handleLoadError err =
            "Keyword is currently unavailable."
                |> pageLoadError (Page.Keyword url) err
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
            , div [ class "row" ] [ viewMap model.keyword.name 12 ]
            ]
        ]


type Msg
    = DismissErrors


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DismissErrors ->
            { model | errors = [] } => Cmd.none


initMap : Model -> Cmd msg
initMap model =
    Util.initMap model.keyword.name <| List.filterMap .gps model.keyword.photos
