module Page.SlideShow exposing (Model, Msg(..), init, subscriptions, toSession, update, view)

{-| Viewing a user's album.
-}

import Browser.Events
import Data.Album exposing (Album)
import Data.Misc
import Data.Photo as Photo
import Data.Url as Url exposing (Url)
import Html exposing (Html, div, text)
import Html.Attributes exposing (class, style)
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
    , notifications : List Notification
    }


type alias Notification =
    { age : Int
    , message : String
    , display : Bool
    }


notification : String -> Notification
notification message =
    { age = 0
    , message = message
    , display = True
    }


help : List Notification
help =
    [ notification "Show help with \"h\""
    , notification "Navigate with left / right arrow"
    , notification "Change timer with up / down arrow"
    , notification "Pause with \"p\" or \"space\""
    , notification "Randomize order with \"r\""
    ]


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
      , notifications = help
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

            Loaded album ->
                div
                    [ style "position" "absolute"
                    , style "width" "100%"
                    , style "height" "100%"
                    , style "top" "0px"
                    , style "left" "0px"
                    , style "transition-property" "background-image"
                    , style "transition-duration" "600ms"
                    , style "transition-timing-function" "ease-in-out"
                    , style "background-color" "black"
                    , style "background-image" <|
                        Util.urlToCssUrl
                            (Photo.biggest model.currentPhoto.scaledPhotos)
                    , style "background-position-x" "center"
                    , style "background-repeat" "no-repeat"
                    , style "background-size" "contain"
                    ]
                <|
                    List.indexedMap viewNotification model.notifications
                        ++ List.map preloadImage album.photos

            Failed ->
                Loading.error "album"
    }


viewNotification : Int -> Notification -> Html Msg
viewNotification index noti =
    let
        top =
            (76 * index) + 20 |> String.fromInt
    in
    div
        [ class "notification notification-default animation-fade-in position-top-left notification-image notification-close-on-click"
        , style "top" (top ++ "px")
        , style "left" "20px"
        , if not noti.display then
            style "opacity" "0"

          else
            style "opacity" "1"
        ]
        [ div [ class "notification-body" ]
            [ div [ class "notification-content" ]
                [ div [ class "notification-desc" ]
                    [ text noti.message ]
                ]
            ]
        ]


preloadImage : Data.Misc.PhotoInAlbum -> Html Msg
preloadImage photo =
    div
        [ style
            "background"
          <|
            Util.urlToCssUrl (Photo.biggest photo.scaledPhotos)
                ++ "no-repeat -9999px -9999px"
        ]
        []


type Msg
    = DismissErrors
    | CompletedAlbumLoad (Result Http.Error Album)
    | PassedSlowLoadThreshold
    | KeyMsg String
    | NextPhoto Time.Posix
    | UpdateNotifications Time.Posix
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
                    let
                        new =
                            model.nextPhotoDelay + 1000

                        noti =
                            notification <|
                                "Timer set to "
                                    ++ String.fromFloat (new / 1000)
                                    ++ "s between photos"
                    in
                    ( { model
                        | nextPhotoDelay = new
                        , notifications = model.notifications ++ [ noti ]
                      }
                    , Cmd.none
                    )

                "ArrowDown" ->
                    let
                        new =
                            max (model.nextPhotoDelay - 1000) 3000

                        noti =
                            notification <|
                                "Timer set to "
                                    ++ String.fromFloat (new / 1000)
                                    ++ "s between photos"
                    in
                    ( { model
                        | nextPhotoDelay = new
                        , notifications = model.notifications ++ [ noti ]
                      }
                    , Cmd.none
                    )

                " " ->
                    ( togglePause model
                    , Cmd.none
                    )

                "p" ->
                    ( togglePause model
                    , Cmd.none
                    )

                "r" ->
                    ( { model | notifications = model.notifications ++ [ notification "Photos have been randomized" ] }
                    , Random.generate Randomize <|
                        Random.pair
                            (Random.List.shuffle model.presented)
                            (Random.List.shuffle model.notPresented)
                    )

                "h" ->
                    ( { model | notifications = help }, Cmd.none )

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

        UpdateNotifications _ ->
            let
                newAge =
                    List.map
                        (\noti ->
                            { noti | age = noti.age + 1 }
                        )
                        model.notifications

                hide =
                    List.map
                        (\noti ->
                            if noti.age == 5 then
                                { noti | display = False }

                            else
                                noti
                        )
                        newAge

                newNotifications =
                    List.filter (\noti -> noti.age < 7) hide
            in
            ( { model | notifications = newNotifications }, Cmd.none )

        Randomize ( presented, notPresented ) ->
            ( { model | presented = presented, notPresented = notPresented }, Cmd.none )


togglePause : Model -> Model
togglePause model =
    { model
        | paused = not model.paused
        , notifications =
            model.notifications
                ++ [ notification
                        (if model.paused then
                            "Unpaused"

                         else
                            "Paused"
                        )
                   ]
    }


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
        , Time.every 1000 UpdateNotifications
        ]


toSession : Model -> Session
toSession model =
    model.session
