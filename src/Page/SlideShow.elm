module Page.SlideShow exposing (Model, Msg(..), init, subscriptions, toSession, update, view)

{-| Viewing a user's album.
-}

import Browser.Events
import Data.Album exposing (Album)
import Data.Misc
import Data.Url as Url exposing (Url)
import Html exposing (Html, div)
import Html.Attributes exposing (style)
import Http
import Json.Decode as Decode
import List.Extra
import Loading
import Log
import Random
import Random.List
import Request.Album
import Session exposing (Session)
import Task
import Time
import Util exposing (Status(..))



-- MODEL --


type alias Model =
    { session : Session
    , errors : List String
    , nextPhotoDelay : Float
    , paused : Bool
    , album : Status Album
    , currentPhoto : Data.Misc.PhotoInAlbum
    , presented : List Data.Misc.PhotoInAlbum
    , notPresented : List Data.Misc.PhotoInAlbum
    }


init : Session -> Url -> ( Model, Cmd Msg )
init session url =
    ( { session = session
      , errors = []
      , nextPhotoDelay = 6000
      , paused = False
      , album = Loading

      -- TODO: This is currently because i would prefer this to not be maybe...
      , currentPhoto =
            { url = Url.fromString ""
            , originalImageURL = ""
            , scaledPhotos = []
            , gps = Nothing
            }
      , presented = []
      , notPresented = []
      }
    , Cmd.batch
        [ Request.Album.get url CompletedAlbumLoad
        , Task.perform (\_ -> PassedSlowLoadThreshold) Loading.slowThreshold
        ]
    )



-- VIEW --


view : Model -> { title : String, content : Html Msg }
view model =
    { title =
        Util.statusToMaybe model.album
            |> Maybe.map .name
            |> Maybe.withDefault "Slideshow"
    , content =
        case model.album of
            Loading ->
                Loading.icon

            LoadingSlowly ->
                Loading.icon

            Loaded _ ->
                div
                    [ style "position" "absolute"
                    , style "width" "100%"
                    , style "height" "100%"
                    , style "top" "0px"
                    , style "left" "0px"
                    , style "transition-property" "background-image"
                    , style "transition-duration" "1s"
                    , style "transition-timing-function" "ease-in-out"
                    , style "background-color" "black"
                    , style "background-image" ("url(" ++ model.currentPhoto.originalImageURL ++ ")")
                    , style "background-position-x" "center"
                    , style "background-repeat" "no-repeat"
                    , style "background-size" "contain"
                    ]
                    []

            Failed ->
                Loading.error "album"
    }


type Msg
    = DismissErrors
    | CompletedAlbumLoad (Result Http.Error Album)
    | PassedSlowLoadThreshold
    | KeyMsg String
    | NextPhoto Time.Posix
    | Randomize ( List Data.Misc.PhotoInAlbum, List Data.Misc.PhotoInAlbum )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DismissErrors ->
            ( { model | errors = [] }, Cmd.none )

        CompletedAlbumLoad (Ok album) ->
            case album.photos of
                [] ->
                    ( { model
                        | album = Loaded album
                        , notPresented = []
                      }
                    , Cmd.none
                    )

                h :: t ->
                    ( { model
                        | album = Loaded album
                        , notPresented = t
                        , currentPhoto = h
                      }
                    , Cmd.none
                    )

        CompletedAlbumLoad (Err err) ->
            ( { model | album = Failed }
            , Log.httpError err
            )

        PassedSlowLoadThreshold ->
            ( model, Cmd.none )

        KeyMsg code ->
            case code of
                "ArrowRight" ->
                    ( nextPhoto model, Cmd.none )

                "ArrowLeft" ->
                    ( previousPhoto model, Cmd.none )

                "ArrowUp" ->
                    ( { model | nextPhotoDelay = model.nextPhotoDelay + 1000 }, Cmd.none )

                "ArrowDown" ->
                    let
                        new =
                            max (model.nextPhotoDelay - 1000) 3000
                    in
                    ( { model | nextPhotoDelay = new }, Cmd.none )

                " " ->
                    ( { model | paused = not model.paused }, Cmd.none )

                "r" ->
                    ( model
                    , Random.generate Randomize <|
                        Random.pair
                            (Random.List.shuffle model.presented)
                            (Random.List.shuffle model.notPresented)
                    )

                _ ->
                    --    let
                    --        _ =
                    --            Debug.log "key" str
                    --    in
                    ( model, Cmd.none )

        NextPhoto _ ->
            if model.paused then
                ( model, Cmd.none )

            else
                ( nextPhoto model, Cmd.none )

        Randomize ( presented, notPresented ) ->
            ( { model | presented = presented, notPresented = notPresented }, Cmd.none )


nextPhoto : Model -> Model
nextPhoto model =
    case model.notPresented of
        [] ->
            case model.presented of
                [] ->
                    model

                h :: t ->
                    { model
                        | notPresented = t ++ [ model.currentPhoto ]
                        , presented = []
                        , currentPhoto = h
                    }

        h :: t ->
            { model
                | currentPhoto = h
                , notPresented = t
                , presented = model.presented ++ [ model.currentPhoto ]
            }


previousPhoto : Model -> Model
previousPhoto model =
    case List.Extra.last model.presented of
        Nothing ->
            case List.Extra.last model.notPresented of
                Nothing ->
                    model

                Just last ->
                    { model
                        | currentPhoto = last
                        , notPresented = []
                        , presented = model.currentPhoto :: Maybe.withDefault [] (List.Extra.init model.notPresented)
                    }

        Just last ->
            { model
                | currentPhoto = last
                , notPresented = model.currentPhoto :: model.notPresented
                , presented = Maybe.withDefault [] (List.Extra.init model.presented)
            }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Browser.Events.onKeyDown <| Decode.map KeyMsg (Decode.field "key" Decode.string)
        , Time.every model.nextPhotoDelay NextPhoto
        ]


toSession : Model -> Session
toSession model =
    model.session
