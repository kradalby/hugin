module Page.Album exposing (Model, Msg(..), init, initMap, subscriptions, toSession, update, view, viewDownloadButton)

{-| Viewing a user's album.
-}

import Data.Album exposing (Album)
import Data.Misc exposing (AlbumInAlbum)
import Data.Photo as Photo
import Data.Url as Url exposing (Url)
import Html exposing (Html, a, div, h4, i, img, input, span, text)
import Html.Attributes exposing (alt, attribute, class, download, href, id, src, title, type_, value, width)
import Html.Events exposing (onClick, onInput)
import Html.Lazy
import Http
import Loading
import Log
import Request.Album
import Request.Zip
import Route
import Session exposing (Session)
import Task
import Util exposing (Status(..))
import Views.Assets as Assets
import Views.Errors as Errors
import Views.Misc exposing (loading, viewKeywords, viewMap, viewPath, viewPhotos)



-- MODEL --


type alias Model =
    { session : Session
    , errors : List String

    -- Nothing means the backend offered no archive, so no button.
    , archive : Maybe Request.Zip.Archive
    , keywordFilter : String
    , album : Status Album
    }


init : Session -> Url -> ( Model, Cmd Msg )
init session url =
    ( { session = session
      , errors = []
      , archive = Nothing
      , keywordFilter = ""
      , album = Loading
      }
    , Cmd.batch
        [ Request.Album.get url CompletedAlbumLoad
        , Request.Zip.available url CompletedZipProbe
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
                            , viewDownloadButton album model.archive
                            ]
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


viewSlideShowButton : Album -> Html Msg
viewSlideShowButton album =
    div [ class "ml-auto mr-2" ] [ a [ Route.href <| Route.SlideShow <| Url.toRoute album.url ] [ i [ class "fas fa-images text-white" ] [] ] ]


{-| Absent unless the backend answered the probe. `download ""` also makes
`elm/browser`'s link diverter skip the click; without it `Main`'s `ClickedLink`
swallows it and the button does nothing.
-}
viewDownloadButton : Album -> Maybe Request.Zip.Archive -> Html Msg
viewDownloadButton album archive =
    case archive of
        Nothing ->
            text ""

        Just { size } ->
            let
                label =
                    "Download album" ++ Views.Misc.sizeSuffix size
            in
            div [ class "mr-2" ]
                [ a
                    [ href (Url.toZipUrl album.url)
                    , download ""
                    , title label

                    -- Font Awesome makes the icon aria-hidden, so without this
                    -- the link has no accessible name.
                    , attribute "aria-label" label
                    , onClick CopyRightNotice
                    ]
                    [ i [ class "fas fa-download text-white" ] [] ]
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
            [ a [ class "", Route.href (Route.Album (Url.toRoute album.url)) ]
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
    | CopyRightNotice
    | UpdateKeywordFilter String
    | CompletedAlbumLoad (Result Http.Error Album)
    | CompletedZipProbe (Result Http.Error (Maybe Request.Zip.Archive))
    | PassedSlowLoadThreshold


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DismissErrors ->
            ( { model | errors = [] }, Cmd.none )

        -- The anchor downloads; this only raises the notice alongside it.
        CopyRightNotice ->
            ( { model
                | errors =
                    [ "Remember to ask and credit the photographer before using the images!"
                    ]
              }
            , Cmd.none
            )

        UpdateKeywordFilter value ->
            ( { model | keywordFilter = value }, Cmd.none )

        CompletedZipProbe (Ok archive) ->
            ( { model | archive = archive }, Cmd.none )

        -- A 404 is an ordinary answer and never reaches here; a timeout or a
        -- network error silently removing the button is worth a console line.
        CompletedZipProbe (Err err) ->
            ( { model | archive = Nothing }, Log.httpError err )

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
