module Page.Locations exposing (Model, Msg(..), init, subscriptions, toSession, update, view)

{-| Viewing a user's album.
-}

import Data.Location exposing (Locations)
import Data.Url exposing (Url)
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Loading
import Log
import Request.Locations
import Session exposing (Session)
import Task
import Util exposing (Status(..))
import Views.Errors as Errors
import Views.Misc exposing (viewMap)



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
        [ Request.Locations.get url CompletedLocationsLoad
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

        CompletedLocationsLoad (Err _) ->
            ( { model | locations = Failed }
            , Log.error
            )

        PassedSlowLoadThreshold ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


toSession : Model -> Session
toSession model =
    model.session
