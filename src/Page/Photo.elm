module Page.Photo exposing (Model, Msg, init, update, view, initMap)

{-| Viewing a user's photo.
-}

import Data.Photo as Photo exposing (Photo)
import Data.Url as Url exposing (Url)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Lazy
import Http
import Page.Errored exposing (PageLoadError, pageLoadError)
import Request.Photo
import Task exposing (Task)
import Util exposing ((=>), pair, viewIf, formatExposureTime, cleanOwnerToName)
import Views.Errors as Errors
import Views.Page as Page
import Views.Misc exposing (viewKeywords, viewPath, viewMap)
import Maybe.Extra
import Route exposing (Route)
import Date.Format


-- MODEL --


type alias Model =
    { errors : List String
    , photo : Photo
    }


init : Url -> Task PageLoadError Model
init url =
    let
        loadPhoto =
            Request.Photo.get url
                |> Http.toTask

        handleLoadError _ =
            "Photo is currently unavailable."
                |> pageLoadError (Page.Photo url)
    in
        Task.map (Model []) loadPhoto
            |> Task.mapError handleLoadError



-- VIEW --


view : Model -> Html Msg
view model =
    let
        photo =
            model.photo
    in
        div [ class "photo-page" ]
            [ Errors.view DismissErrors model.errors
            , div [ class "container-fluid" ]
                [ div [ class "row bg-darklight" ]
                    [ viewPath photo.parents photo.name
                    , viewDownloadButton photo
                    ]
                , div [ class "row" ] [ viewImage photo ]
                , div [ class "row" ]
                    [ viewKeywords "People" photo.people
                    , viewKeywords "Tags" photo.keywords
                    ]
                , div [ class "row" ]
                    [ Html.Lazy.lazy viewInformation photo
                    , viewMap
                    ]
                ]
            ]


viewDownloadButton : Photo -> Html Msg
viewDownloadButton photo =
    div [ class "ml-auto mr-2" ] [ a [ href photo.originalImageURL, downloadAs photo.name ] [ i [ class "fas fa-download text-white" ] [] ] ]


viewImage : Photo -> Html Msg
viewImage photo =
    let
        scaled =
            List.map
                (\img ->
                    source
                        [ media <| "(max-width: " ++ (toString img.maxResolution) ++ "px)"
                        , attribute "srcset" img.url
                        ]
                        []
                )
                photo.scaledPhotos

        image =
            case photo.scaledPhotos of
                [] ->
                    img [ src <| Photo.biggest photo.scaledPhotos, class "mx-auto d-block img-fluid" ] []

                scaledPhotos ->
                    img [ src <| Photo.biggest scaledPhotos, class "mx-auto d-block img-fluid" ] []
    in
        div [ class "col-12 col-sm-12 col-md-12 col-lg-12 col-xl-12 m-0 p-0" ]
            [ div [ class "mx-auto" ]
                [ div []
                    [ node "picture"
                        []
                      <|
                        scaled
                            ++ [ image ]
                    , a
                        (case photo.previous of
                            Nothing ->
                                []

                            Just url ->
                                [ Route.href (Route.Photo (Url.urlToString url)) ]
                        )
                        [ div [ class "previous-image-overlay" ] [] ]
                    , a
                        (case photo.next of
                            Nothing ->
                                []

                            Just url ->
                                [ Route.href (Route.Photo (Url.urlToString url)) ]
                        )
                        [ div [ class "next-image-overlay" ] [] ]
                    ]
                ]
            ]


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


type Msg
    = DismissErrors


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        photo =
            model.photo
    in
        case msg of
            DismissErrors ->
                { model | errors = [] } => Cmd.none


initMap : Model -> Cmd msg
initMap model =
    case model.photo.gps of
        Nothing ->
            Util.initMap []

        Just gps ->
            Util.initMap [ gps ]
