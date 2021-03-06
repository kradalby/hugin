module Page.Photo exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Browser.Events
import Data.Photo as Photo exposing (Photo)
import Data.Url as Url exposing (Url)
import File.Download as Download
import Html exposing (Attribute, Html, a, button, div, h5, hr, i, img, p, span, table, tbody, td, text, th, tr)
import Html.Attributes exposing (attribute, class, href, id, scope, src, style, type_)
import Html.Events exposing (onClick)
import Html.Lazy
import Http
import Json.Decode as Decode
import Loading
import Log
import Maybe.Extra exposing (orElse)
import Request.Photo
import Route
import Session exposing (Session)
import Task
import Util exposing (Status(..), cleanOwnerToName, viewIf)
import Views.Errors as Errors
import Views.Misc exposing (scaledImg, viewKeywords, viewMap, viewPath)



-- MODEL --


type alias Model =
    { session : Session
    , errors : List String
    , showHelpModal : Bool
    , photo : Status Photo
    }


init : Session -> Url -> ( Model, Cmd Msg )
init session url =
    ( { session = session
      , errors = []
      , showHelpModal = False
      , photo = Loading
      }
    , Cmd.batch
        [ Request.Photo.get url CompletedPhotoLoad
        , Task.perform (\_ -> PassedSlowLoadThreshold) Loading.slowThreshold
        ]
    )



-- VIEW --


view : Model -> { title : String, content : Html Msg }
view model =
    { title =
        Util.statusToMaybe model.photo
            |> Maybe.map .name
            |> Maybe.withDefault "Photo"
    , content =
        case model.photo of
            Loading ->
                Loading.icon

            LoadingSlowly ->
                Loading.icon

            Loaded photo ->
                div [ class "photo-page" ]
                    [ div [ class "container-fluid" ]
                        [ div [ class "row bg-darklight" ]
                            [ viewPath photo.parents photo.name
                            , div [ class "col-2 pr-2 text-right" ]
                                [ viewHelpButton
                                , viewDownloadButton photo
                                ]
                            ]
                        , Errors.view DismissErrors model.errors
                        , viewIf model.showHelpModal (viewHelpModal photo)
                        , div [ class "row" ] [ viewImage photo ]
                        , div [ class "row" ]
                            [ viewKeywords "People" photo.people
                            , viewKeywords "Tags" photo.keywords
                            ]
                        , div [ class "row" ]
                            [ Html.Lazy.lazy viewInformation photo
                            , viewMap photo.name 12 12 6 6 6
                            ]
                        ]
                    ]

            Failed ->
                Loading.error "photo"
    }


viewDownloadButton : Photo -> Html Msg
viewDownloadButton photo =
    span [ class "" ]
        [ a [ onClick CopyRightNotice, href photo.originalImageURL ]
            [ i [ class "fas fa-download text-white" ] []
            ]
        ]


viewHelpButton : Html Msg
viewHelpButton =
    span [ class "pr-2" ]
        [ span [ onClick ToggleHelpModal ]
            [ i [ class "fas fa-info-circle text-white" ] []
            ]
        ]


previousHref : Photo -> Attribute msg
previousHref photo =
    Maybe.map Url.urlToString photo.previous
        |> Maybe.map (\url -> Route.href (Route.Photo url))
        |> Maybe.withDefault (href "")


nextHref : Photo -> Attribute msg
nextHref photo =
    Maybe.map Url.urlToString photo.next
        |> Maybe.map (\url -> Route.href (Route.Photo url))
        |> Maybe.withDefault (href "")


viewImage : Photo -> Html Msg
viewImage photo =
    let
        imageTag =
            viewImageTag photo
    in
    div [ class "col-12 col-sm-12 col-md-12 col-lg-12 col-xl-12 m-0 p-0" ]
        [ div [ class "mx-auto" ]
            [ div [ id "photo" ]
                [ imageTag
                , a [ previousHref photo ]
                    [ div [ class "previous-image-overlay" ] [] ]
                , a [ nextHref photo ]
                    [ div [ class "next-image-overlay" ] [] ]
                ]
            ]
        ]


viewImageTag : Photo -> Html Msg
viewImageTag photo =
    case photo.scaledPhotos of
        [] ->
            img [ src <| Photo.biggest photo.scaledPhotos, class "mx-auto d-block img-fluid" ] []

        scaledPhotos ->
            scaledImg scaledPhotos


viewInformation : Photo -> Html Msg
viewInformation photo =
    let
        row : String -> String -> Html Msg
        row name value =
            tr []
                [ th [ scope "row" ]
                    [ text name ]
                , td []
                    [ text value
                    ]
                ]

        original =
            tr []
                [ th [ scope "row" ]
                    [ text "Original" ]
                , td [] [ a [ href photo.originalImageURL ] [ text "Link" ] ]
                ]

        rows =
            [ photo.owner |> Maybe.map (cleanOwnerToName >> row "Photographer")
            , photo.dateTime |> Maybe.map (Util.formatPhotoDate >> row "Date")
            , photo.cameraMake |> Maybe.map (row "Camera")
            , photo.cameraModel |> Maybe.map (row "Model")
            , photo.lensModel |> Maybe.map (row "Lens")

            -- If the formatted version is available, use it, if not try the raw
            -- value.
            , photo.focalLengthFormatted
                |> orElse
                    (photo.focalLength
                        |> Maybe.map String.fromFloat
                    )
                |> Maybe.map (row "Focal length")
            , photo.fNumberFormatted
                |> orElse
                    (photo.fNumber
                        |> Maybe.map String.fromFloat
                    )
                |> Maybe.map (row "f-stop")

            -- , photo.exposureTimeFormatted |> orElse photo.exposureTime |> Maybe.map (Util.formatExposureTime >> row "Shutter speed")
            , photo.exposureTimeFormatted |> Maybe.map (row "Exposure time")
            , photo.shutterSpeedFormatted |> Maybe.map (row "Shutter speed")
            , photo.meteringModeFormatted |> Maybe.map (row "Metering mode")
            , photo.apertureFormatted |> Maybe.map (row "Aperture")
            , List.head photo.isoSpeed
                |> Maybe.map String.fromInt
                |> Maybe.map (row "ISO")
            , photo.gps
                |> Maybe.map .altitude
                |> Maybe.map (Util.formatAltitude >> row "Altitude")
            , Just original
            ]
    in
    div [ class "col-12 col-sm-12 col-md-6 col-lg-6 col-xl-6" ]
        [ div [ class "mt-3" ]
            [ table [ class "table" ]
                [ tbody []
                    (Maybe.Extra.values
                        rows
                    )
                ]
            ]
        ]


viewHelpModal : Photo -> Html Msg
viewHelpModal photo =
    div [ style "display" "block", attribute "aria-hidden" "false", attribute "aria-labelledby" "helpModal", class "modal", id "helpModal", attribute "role" "dialog", attribute "tabindex" "-1" ]
        [ div [ class "modal-dialog modal-dialog-centered", attribute "role" "document" ]
            [ div [ class "modal-content" ]
                [ div [ class "modal-header" ]
                    [ h5 [ class "modal-title", id "helpModalTitle" ]
                        [ text "Help" ]
                    , button [ onClick ToggleHelpModal, attribute "aria-label" "Close", class "close", attribute "data-dismiss" "modal", type_ "button" ]
                        [ span [ attribute "aria-hidden" "true" ]
                            [ text "×" ]
                        ]
                    ]
                , div [ class "modal-body" ]
                    [ p [ class "mx-2" ]
                        [ text "Download a high quality version of the image by clicking "
                        , i [ class "fas fa-download" ] []
                        ]
                    , hr [] []
                    , div [ class "mx-2" ]
                        [ p [] [ text "Navigate to the previous or next image by clicking on the left or right side of the current image:" ]
                        , div [ style "position" "relative" ]
                            [ viewImageTag photo
                            , div
                                [ class "previous-image-help-overlay" ]
                                [ i [ class "fas fa-chevron-left fa-3x text-white center-image-on-help-overlay" ]
                                    []
                                ]
                            , div
                                [ class "next-image-help-overlay" ]
                                [ i [ class "fas fa-chevron-right fa-3x text-white center-image-on-help-overlay" ]
                                    []
                                ]
                            ]
                        ]
                    , hr [] []
                    , p [ class "mx-2" ]
                        [ text "On desktop, navigate through images by pressing "
                        , i [ class "fas fa-caret-square-left" ] []
                        , text " to navigate to the previous image and "
                        , i [ class "fas fa-caret-square-right" ] []
                        , text " to navigate to the next image"
                        ]
                    ]
                , div [ class "modal-footer" ]
                    [ button [ onClick ToggleHelpModal, class "btn btn-secondary", attribute "data-dismiss" "modal", type_ "button" ]
                        [ text "Close" ]
                    ]
                ]
            ]
        ]


type Msg
    = DismissErrors
    | ToggleHelpModal
    | CopyRightNotice
    | KeyMsg String
    | CompletedPhotoLoad (Result Http.Error Photo)
    | PassedSlowLoadThreshold


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DismissErrors ->
            ( { model | errors = [] }, Cmd.none )

        ToggleHelpModal ->
            ( { model
                | showHelpModal = not model.showHelpModal
              }
            , Cmd.none
            )

        CopyRightNotice ->
            case model.photo of
                Loaded photo ->
                    ( { model
                        | errors =
                            [ "Remember to ask and credit the photographer before using the image!"
                            ]
                      }
                    , Download.url photo.originalImageURL
                    )

                _ ->
                    ( model, Cmd.none )

        KeyMsg code ->
            case model.photo of
                Loaded photo ->
                    case code of
                        "ArrowLeft" ->
                            case photo.previous of
                                Nothing ->
                                    ( model, Cmd.none )

                                Just url ->
                                    ( model
                                    , Route.pushUrl
                                        (Session.navKey model.session)
                                        (Route.Photo (Url.urlToString url))
                                    )

                        "ArrowRight" ->
                            case photo.next of
                                Nothing ->
                                    ( model, Cmd.none )

                                Just url ->
                                    ( model
                                    , Route.pushUrl
                                        (Session.navKey model.session)
                                        (Route.Photo (Url.urlToString url))
                                    )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        CompletedPhotoLoad (Ok photo) ->
            ( { model | photo = Loaded photo }, initMap photo )

        CompletedPhotoLoad (Err err) ->
            ( { model | photo = Failed }
            , Log.httpError err
            )

        PassedSlowLoadThreshold ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Browser.Events.onKeyDown <| Decode.map KeyMsg (Decode.field "key" Decode.string)
        ]


initMap : Photo -> Cmd msg
initMap photo =
    case photo.gps of
        Nothing ->
            Util.initMap photo.name []

        Just gps ->
            Util.initMap photo.name [ gps ]


toSession : Model -> Session
toSession model =
    model.session
