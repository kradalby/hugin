module Page.Photo exposing (Model, Msg, init, update, view)

{-| Viewing a user's photo.
-}

import Data.Photo exposing (Photo)
import Data.Photo as Photo exposing (Photo)
import Data.Url as Url exposing (Url)
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Page.Errored exposing (PageLoadError, pageLoadError)
import Request.Photo
import Task exposing (Task)
import Util exposing ((=>), pair, viewIf, googleMap, googleMapMarker)
import Views.Errors as Errors
import Views.Page as Page
import Views.Misc exposing (viewKeywords)
import Maybe.Extra


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
                [ div [ class "row" ] [ viewImage photo ]
                , div [ class "row" ]
                    [ viewKeywords "People" photo.people
                    , viewKeywords "Tags" photo.keywords
                    ]
                , div [ class "row" ]
                    [ viewInformation photo
                    , viewMap photo
                    ]
                ]
            ]


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
    in
        div [ class "col-12 col-sm-12 col-md-12 col-lg-12 col-xl-12 m-0 p-0" ]
            [ div [ class "mx-auto" ]
                [ node "picture"
                    []
                  <|
                    scaled
                        ++ [ img [ src photo.originalImageURL, class "img-fluid" ] [] ]
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

        rowWithToString name value =
            row name (toString value)

        rows =
            [ photo.cameraMake |> Maybe.map (row "Camera")
            , photo.cameraModel |> Maybe.map (row "Model")
            , photo.lensModel |> Maybe.map (row "Lens")
            , photo.focalLength |> Maybe.map (rowWithToString "Focal length")
            , photo.fNumber |> Maybe.map (rowWithToString "f/")
            , photo.shutterSpeed |> Maybe.map (rowWithToString "Shutter speed")
            , (List.head photo.isoSpeed) |> Maybe.map (rowWithToString "ISO")
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


viewMap : Photo -> Html Msg
viewMap photo =
    div [ class "col-12 col-sm-12 col-md-6 col-lg-6 col-xl-6" ]
        [ div [ class "mt-3 mb-5" ]
            (case photo.gps of
                Nothing ->
                    []

                Just gps ->
                    [ googleMap
                        [ attribute "api-key" "AIzaSyDO4CHjsXnGLSDbrlmG7tOOr3OMcKt4fQI"
                        , attribute "fit-to-markers" ""
                        , attribute "disable-default-ui" "true"
                        , attribute "disable-zoom" "true"
                        ]
                        [ googleMapMarker
                            [ attribute "latitude" (toString gps.latitude)
                            , attribute "longitude" (toString gps.longitude)
                            , attribute "draggable" "false"
                            , attribute "slot" "markers"
                            ]
                            []
                        ]
                    ]
            )
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
