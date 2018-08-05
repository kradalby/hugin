module Page.Locations exposing (Model, Msg(..), init, update, view)

{-| Viewing a user's album.
-}

import Data.Location as Location exposing (Locations)
import Data.Misc exposing (..)
import Data.Url as Url exposing (Url)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Lazy
import Http
import Page.Errored exposing (PageLoadError, pageLoadError)
import Request.Locations
import Task exposing (Task)
import Util exposing ((=>), pair, viewIf)
import Views.Errors as Errors
import Views.Assets as Assets
import Views.Page as Page
import Views.Misc exposing (viewKeywords, viewPath, viewPhotos, viewPhoto, viewMap)
import Route exposing (Route)


-- MODEL --


type alias Model =
    { errors : List String
    , locations : Locations
    }


init : Url -> Task PageLoadError Model
init url =
    let
        loadLocations =
            Request.Locations.get url
                |> Http.toTask

        handleLoadError _ =
            "Locations is currently unavailable."
                |> pageLoadError (Page.Locations url)
    in
        Task.map (Model []) loadLocations
            |> Task.mapError handleLoadError



-- VIEW --


view : Model -> Html Msg
view model =
    div [ class "album-page" ]
        [ Errors.view DismissErrors
            model.errors
        , div
            [ class "container-fluid" ]
            [ div [ class "row" ] [ viewMap "locations" ]
            ]
        ]


type Msg
    = DismissErrors


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DismissErrors ->
            { model | errors = [] } => Cmd.none
