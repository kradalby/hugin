module Page.Album exposing (Model, Msg(..), init, initMap, subscriptions, toSession, update, view)

{-| Viewing a user's album.
-}

import Data.Album exposing (Album)
import Data.Misc exposing (AlbumInAlbum)
import Data.Photo as Photo
import Data.Url as Url exposing (Url)
import Html exposing (Html, a, button, div, h4, h5, hr, i, img, input, p, span, text)
import Html.Attributes exposing (alt, attribute, class, id, src, style, type_, value, width)
import Html.Events exposing (onClick, onInput)
import Html.Lazy
import Http
import Loading
import Log
import Ports
import Request.Album
import Route
import Session exposing (Session)
import Task
import Util exposing (Status(..), viewIf)
import Views.Assets as Assets
import Views.Errors as Errors
import Views.Misc exposing (loading, viewKeywords, viewMap, viewPath, viewPhotos)



-- MODEL --


type alias Model =
    { session : Session
    , errors : List String
    , showDownloadModal : Bool
    , keywordFilter : String
    , album : Status Album
    }


init : Session -> Url -> ( Model, Cmd Msg )
init session url =
    ( { session = session
      , errors = []
      , showDownloadModal = False
      , keywordFilter = ""
      , album = Loading
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
            |> Maybe.withDefault "Album"
    , content =
        case model.album of
            Loading ->
                Loading.icon

            LoadingSlowly ->
                Loading.icon

            Loaded album ->
                div [ class "album-page" ]
                    [ Errors.view DismissErrors
                        model.errors
                    , div
                        [ class "container-fluid" ]
                        [ div [ class "row bg-darklight" ]
                            [ viewPath album.parents album.name
                            , viewSlideShowButton album

                            --, viewIf (album.photos /= []) viewDownloadButton
                            ]
                        , viewIf model.showDownloadModal (viewDownloadModal model)
                        , div [ class "row" ]
                            [ Html.Lazy.lazy viewNestedAlbums album.albums ]
                        , div [ class "row" ] [ Html.Lazy.lazy viewPhotos album.photos ]
                        , div [ class "row" ] [ viewKeywordFilter model.keywordFilter ]
                        , div [ class "row" ]
                            [ Html.Lazy.lazy2 viewKeywords
                                "People"
                              <|
                                Util.fuzzyKeywordReduce model.keywordFilter album.people
                            , Html.Lazy.lazy2 viewKeywords
                                "Tags"
                              <|
                                Util.fuzzyKeywordReduce model.keywordFilter album.keywords
                            ]
                        , div [ class "row" ] [ viewMap album.name 12 12 12 12 12 ]
                        ]
                    ]

            Failed ->
                Loading.error "album"
    }



-- viewDownloadButton : Html Msg
-- viewDownloadButton =
--     div [ class "ml-auto mr-2" ] [ span [ onClick ToggleDownloadModal ] [ i [ class "fas fa-download text-white" ] [] ] ]


viewSlideShowButton : Album -> Html Msg
viewSlideShowButton album =
    div [ class "ml-auto mr-2" ] [ a [ Route.href <| Route.SlideShow <| Url.urlToString album.url ] [ i [ class "fas fa-images text-white" ] [] ] ]


viewDownloadModal : Model -> Html Msg
viewDownloadModal _ =
    div [ style "display" "block", attribute "aria-hidden" "false", attribute "aria-labelledby" "downloadModal", class "modal", id "downloadModal", attribute "role" "dialog", attribute "tabindex" "-1" ]
        [ div [ class "modal-dialog modal-dialog-centered", attribute "role" "document" ]
            [ div [ class "modal-content" ]
                [ div [ class "modal-header" ]
                    [ h5 [ class "modal-title", id "downloadModalTitle" ]
                        [ text "Download album" ]
                    , button [ onClick ToggleDownloadModal, attribute "aria-label" "Close", class "close", attribute "data-dismiss" "modal", type_ "button" ]
                        [ span [ attribute "aria-hidden" "true" ]
                            [ text "×" ]
                        ]
                    ]
                , div [ class "modal-body" ]
                    [ div [ class "alert alert-danger", attribute "role" "alert" ]
                        [ text "This feature is experimental, and will probably only work in Chrome-based browsers." ]
                    , hr [] []
                    , p [ class "ml-2 mr-2" ] [ text "If you want to republish or use the photos you download, please ask the photographer and remember to credit." ]
                    ]
                , div [ class "modal-footer" ]
                    [ button [ onClick ToggleDownloadModal, class "btn btn-secondary", attribute "data-dismiss" "modal", type_ "button" ]
                        [ text "Close" ]
                    , button [ onClick Download, class "btn btn-primary", type_ "button" ]
                        [ text "Download" ]
                    ]
                ]
            ]
        ]


viewNestedAlbums : List AlbumInAlbum -> Html Msg
viewNestedAlbums albums =
    case albums of
        [] ->
            text ""

        _ ->
            div [ class "col-12 col-sm-12 col-md-12 col-lg-12 col-xl-12 p-0 mb-5" ]
                [ div [ class "row m-0" ] <|
                    List.map viewNestedAlbum (List.sortBy .name albums)
                ]


viewNestedAlbum : AlbumInAlbum -> Html Msg
viewNestedAlbum album =
    div [ class "col-12 col-sm-6 col-md-6 col-lg-4 col-xl-3 mt-3 d-flex justify-content-around" ]
        [ div [ class "image-album-container" ]
            [ a [ class "", Route.href (Route.Album (Url.urlToString album.url)) ]
                [ case album.scaledPhotos of
                    [] ->
                        img [ Assets.src Assets.placeholder, alt "Placeholder image", width 300, loading "lazy" ] []

                    _ ->
                        img [ src (Photo.thumbnail album.scaledPhotos 300), loading "lazy" ] []
                , h4 [] [ text album.name ]
                ]
            ]
        ]


viewKeywordFilter : String -> Html Msg
viewKeywordFilter keywordFilter =
    div [ class "input-group mb-3" ]
        [ div [ class "input-group-prepend" ]
            [ span [ class "input-group-text", id "inputGroup-sizing-default" ]
                [ text "Keyword filter" ]
            ]
        , input [ attribute "aria-describedby" "inputGroup-sizing-default", attribute "aria-label" "Keyword filter", class "form-control", type_ "text", onInput UpdateKeywordFilter, value keywordFilter ]
            []
        ]


type Msg
    = DismissErrors
    | ToggleDownloadModal
    | Download
    | UpdateKeywordFilter String
    | CompletedAlbumLoad (Result Http.Error Album)
    | PassedSlowLoadThreshold


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DismissErrors ->
            ( { model | errors = [] }, Cmd.none )

        ToggleDownloadModal ->
            ( { model
                | showDownloadModal = not model.showDownloadModal
              }
            , Cmd.none
            )

        Download ->
            let
                urls =
                    case model.album of
                        Loaded album ->
                            List.map
                                .originalImageURL
                                album.photos

                        _ ->
                            []
            in
            ( model, Ports.downloadImages urls )

        UpdateKeywordFilter value ->
            ( { model | keywordFilter = value }, Cmd.none )

        CompletedAlbumLoad (Ok album) ->
            ( { model | album = Loaded album }, initMap album )

        CompletedAlbumLoad (Err err) ->
            ( { model | album = Failed }
            , Log.httpError err
            )

        PassedSlowLoadThreshold ->
            ( model, Cmd.none )


initMap : Album -> Cmd msg
initMap album =
    Util.initMap album.name <| List.filterMap .gps album.photos


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


toSession : Model -> Session
toSession model =
    model.session
