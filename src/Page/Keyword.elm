module Page.Keyword exposing (Model, Msg(..), init, initMap, subscriptions, toSession, update, view)

{-| Viewing a user's album.
-}

import Data.Keyword as Keyword exposing (Keyword)
import Data.Url as Url exposing (Url)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Lazy
import Http
import Loading
import Log
import Request.Keyword
import Session exposing (Session)
import Task exposing (Task)
import Util exposing (Status(..), viewIf)
import Views.Errors as Errors
import Views.Misc exposing (viewMap, viewPhoto, viewPhotos)



-- MODEL --


type alias Model =
    { session : Session
    , errors : List String
    , keyword : Status Keyword
    }


init : Session -> Url -> ( Model, Cmd Msg )
init session url =
    ( { session = session
      , errors = []
      , keyword = Loading
      }
    , Cmd.batch
        [ Request.Keyword.get url
            |> Http.toTask
            |> Task.attempt CompletedKeywordLoad
        , Task.perform (\_ -> PassedSlowLoadThreshold) Loading.slowThreshold
        ]
    )



-- VIEW --


view : Model -> { title : String, content : Html Msg }
view model =
    { title =
        Util.statusToMaybe model.keyword
            |> Maybe.map .name
            |> Maybe.withDefault "Keyword"
    , content =
        case model.keyword of
            Loading ->
                -- Todo: Nice loading
                text ""

            LoadingSlowly ->
                -- Todo: Nice loading
                Loading.icon

            Loaded keyword ->
                div [ class "album-page" ]
                    [ Errors.view DismissErrors
                        model.errors
                    , div
                        [ class "container-fluid" ]
                        [ div [ class "row" ] [ h1 [ class "ml-2" ] [ text keyword.name ] ]
                        , div [ class "row" ] [ Html.Lazy.lazy viewPhotos keyword.photos ]
                        , div [ class "row" ] [ viewMap keyword.name 12 12 12 12 12 ]
                        ]
                    ]

            Failed ->
                Loading.error "keyword"
    }


type Msg
    = DismissErrors
    | CompletedKeywordLoad (Result Http.Error Keyword)
    | PassedSlowLoadThreshold


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DismissErrors ->
            ( { model | errors = [] }, Cmd.none )

        CompletedKeywordLoad (Ok keyword) ->
            ( { model | keyword = Loaded keyword }, Cmd.none )

        CompletedKeywordLoad (Err err) ->
            ( { model | keyword = Failed }
            , Log.error
            )

        PassedSlowLoadThreshold ->
            ( model, Cmd.none )


initMap : Model -> Cmd msg
initMap model =
    case model.keyword of
        Loaded keyword ->
            Util.initMap keyword.name <| List.filterMap .gps keyword.photos

        _ ->
            Cmd.none


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


toSession : Model -> Session
toSession model =
    model.session
