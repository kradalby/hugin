module Page.Photo exposing (Model, Msg, init, update, view, subscriptions, initMap)

{-| Viewing a user's photo.
-}

import Data.Photo as Photo exposing (Photo)
import Data.Url as Url exposing (Url)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Lazy
import Http
import Page.Errored exposing (PageLoadError, pageLoadError)
import Request.Photo
import Task exposing (Task)
import Util exposing ((=>), pair, viewIf, formatExposureTime, cleanOwnerToName)
import Views.Errors as Errors
import Views.Page as Page
import Views.Misc exposing (viewKeywords, viewPath, viewMap, scaledImg)
import Maybe.Extra
import Route exposing (Route)
import Date.Format
import Keyboard exposing (KeyCode)


-- MODEL --


type alias Model =
    { errors : List String
    , showHelpModal : Bool
    , photo : Photo
    }


init : Url -> Task PageLoadError Model
init url =
    let
        loadPhoto =
            Request.Photo.get url
                |> Http.toTask

        handleLoadError err =
            let
                _ =
                    Debug.log "err: " err
            in
                "Photo is currently unavailable."
                    |> pageLoadError (Page.Photo url) err
    in
        Task.map (Model [] False) loadPhoto
            |> Task.mapError handleLoadError



-- VIEW --


view : Model -> Html Msg
view model =
    let
        photo =
            model.photo
    in
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
                , viewIf model.showHelpModal (viewHelpModal model)
                , div [ class "row" ] [ viewImage photo ]
                , div [ class "row" ]
                    [ viewKeywords "People" photo.people
                    , viewKeywords "Tags" photo.keywords
                    ]
                , div [ class "row" ]
                    [ Html.Lazy.lazy viewInformation photo
                    , viewMap model.photo.name 12 12 6 6 6
                    ]
                ]
            ]


viewDownloadButton : Photo -> Html Msg
viewDownloadButton photo =
    span [ class "" ]
        [ a [ onClick CopyRightNotice, href photo.originalImageURL, downloadAs photo.name ]
            [ i [ class "fas fa-download text-white" ] []
            ]
        ]


viewHelpButton : Html Msg
viewHelpButton =
    span [ class "pr-2" ]
        [ a [ onClick ToggleHelpModal ]
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
                [ div []
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

        rowWithToString name value =
            row name (toString value)

        rows =
            [ photo.copyright |> Maybe.map (cleanOwnerToName >> row "Photographer")
            , photo.dateTime |> Maybe.map (Date.Format.format "%A %d %B %Y %H:%M:%S" >> row "Date")
            , photo.cameraMake |> Maybe.map (row "Camera")
            , photo.cameraModel |> Maybe.map (row "Model")
            , photo.lensModel |> Maybe.map (row "Lens")
            , photo.focalLength |> Maybe.map (rowWithToString "Focal length")
            , photo.fNumber |> Maybe.map (rowWithToString "f/")
            , photo.exposureTime |> Maybe.map (formatExposureTime >> row "Shutter speed")
            , (List.head photo.isoSpeed) |> Maybe.map (rowWithToString "ISO")
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


viewHelpModal : Model -> Html Msg
viewHelpModal model =
    div [ style [ ( "display", "block" ) ], attribute "aria-hidden" "false", attribute "aria-labelledby" "helpModal", class "modal", id "helpModal", attribute "role" "dialog", attribute "tabindex" "-1" ]
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
                        , div [ style [ ( "position", "relative" ) ] ]
                            [ viewImageTag model.photo
                            , div
                                [ class "previous-image-help-overlay" ]
                                [ i [ class "fas fa-chevron-left fa-3x text-white mx-auto d-block" ]
                                    []
                                ]
                            , div
                                [ class "next-image-help-overlay" ]
                                [ i [ class "fas fa-chevron-right fa-3x text-white mx-auto d-block" ]
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
    | KeyMsg KeyCode


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        photo =
            model.photo
    in
        case msg of
            DismissErrors ->
                { model | errors = [] } => Cmd.none

            ToggleHelpModal ->
                { model
                    | showHelpModal = not model.showHelpModal
                }
                    => Cmd.none

            CopyRightNotice ->
                { model | errors = [ "Remember to ask and credit the photographer before using the image!" ] } => Cmd.none

            KeyMsg code ->
                case code of
                    37 ->
                        case photo.previous of
                            Nothing ->
                                ( model, Cmd.none )

                            Just url ->
                                ( model, Route.modifyUrl (Route.Photo (Url.urlToString url)) )

                    39 ->
                        case photo.next of
                            Nothing ->
                                ( model, Cmd.none )

                            Just url ->
                                ( model, Route.modifyUrl (Route.Photo (Url.urlToString url)) )

                    _ ->
                        ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Keyboard.downs KeyMsg
        ]


initMap : Model -> Cmd msg
initMap model =
    case model.photo.gps of
        Nothing ->
            Util.initMap model.photo.name []

        Just gps ->
            Util.initMap model.photo.name [ gps ]
