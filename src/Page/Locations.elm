module Page.Locations exposing (Model, Msg(..), init, subscriptions, toSession, update, view)

{-| Viewing a user's album.
-}

import Data.Location as Location exposing (Locations)
import Data.Misc exposing (..)
import Data.Url as Url exposing (Url)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Lazy
import Http
import Loading
import Log
import Request.Locations
import Route exposing (Route)
import Session exposing (Session)
import Task exposing (Task)
import Util exposing (Status(..))
import Views.Assets as Assets
import Views.Errors as Errors
import Views.Misc exposing (viewKeywords, viewMap, viewPath, viewPhoto, viewPhotos)



-- MODEL --


type alias Model =
    { session : Session
    , errors : List String
    , locations : Status Locations
    }


init : Session -> Url -> ( Model, Cmd Msg )
init session url =
    ( { session = session
      , errors = []
      , locations = Loading
      }
    , Cmd.batch
        [ Request.Locations.get url
            |> Http.toTask
            |> Task.attempt CompletedLocationsLoad
        , Task.perform (\_ -> PassedSlowLoadThreshold) Loading.slowThreshold
        ]
    )



-- VIEW --


view : Model -> { title : String, content : Html Msg }
view model =
    { title = "Locations"
    , content =
        div [ class "album-page" ]
            [ Errors.view DismissErrors
                model.errors
            , div
                [ class "container-fluid" ]
                [ div [ class "row" ] [ viewMap "locations" 12 12 12 12 12 ]
                ]
            ]
    }


type Msg
    = DismissErrors
    | CompletedLocationsLoad (Result Http.Error Locations)
    | PassedSlowLoadThreshold


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DismissErrors ->
            ( { model | errors = [] }, Cmd.none )

        CompletedLocationsLoad (Ok locations) ->
            ( { model | locations = Loaded locations }, Cmd.none )

        CompletedLocationsLoad (Err err) ->
            ( { model | locations = Failed }
            , Log.error
            )

        PassedSlowLoadThreshold ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


toSession : Model -> Session
toSession model =
    model.session
