module Main exposing (main)

import Html exposing (..)
import Http exposing (Error)
import Json.Decode as Decode exposing (Value)
import Navigation exposing (Location)
import Page.Errored as Errored exposing (PageLoadError)
import Page.Album as Album
import Page.Photo as Photo
import Page.Keyword as Keyword
import Page.Locations as Locations
import Page.NotFound as NotFound
import Route exposing (Route)
import Task
import Util exposing ((=>), initMap)
import Views.Page as Page exposing (ActivePage)
import Data.Url
import Request.Helpers exposing (rootUrl)
import Ports


-- WARNING: Based on discussions around how asset management features
-- like code splitting and lazy loading have been shaping up, I expect
-- most of this file to become unnecessary in a future release of Elm.
-- Avoid putting things in here unless there is no alternative!


type Page
    = Blank
    | NotFound
    | Errored PageLoadError
    | Album Data.Url.Url Album.Model
    | Photo Data.Url.Url Photo.Model
    | Keyword Data.Url.Url Keyword.Model
    | Locations Data.Url.Url Locations.Model


type PageState
    = Loaded Page
    | TransitioningFrom Page



-- MODEL --


type alias Model =
    { pageState : PageState
    }


init : Value -> Location -> ( Model, Cmd Msg )
init val location =
    setRoute (Route.fromLocation location)
        { pageState = Loaded initialPage
        }


initialPage : Page
initialPage =
    Blank



-- VIEW --


view : Model -> Html Msg
view model =
    case model.pageState of
        Loaded page ->
            viewPage False page

        TransitioningFrom page ->
            viewPage True page


viewPage : Bool -> Page -> Html Msg
viewPage isLoading page =
    let
        frame =
            Page.frame isLoading
    in
        case page of
            NotFound ->
                NotFound.view
                    |> frame Page.Other

            Blank ->
                -- This is for the very initial page load, while we are loading
                -- data via HTTP. We could also render a spinner here.
                Html.text ""
                    |> frame Page.Other

            Errored (Errored.PageLoadError model) ->
                case model.errorType of
                    Http.BadStatus resp ->
                        case resp.status.code of
                            404 ->
                                NotFound.view
                                    |> frame Page.Other

                            _ ->
                                Errored.view (Errored.PageLoadError model)
                                    |> frame Page.Other

                    _ ->
                        Errored.view (Errored.PageLoadError model)
                            |> frame Page.Other

            Album url subModel ->
                Album.view subModel
                    |> frame (Page.Album url)
                    |> Html.map AlbumMsg

            Photo url subModel ->
                Photo.view subModel
                    |> frame (Page.Photo url)
                    |> Html.map PhotoMsg

            Keyword url subModel ->
                Keyword.view subModel
                    |> frame (Page.Keyword url)
                    |> Html.map KeywordMsg

            Locations url subModel ->
                Locations.view subModel
                    |> frame (Page.Locations url)
                    |> Html.map LocationsMsg



-- SUBSCRIPTIONS --
-- Note: we aren't currently doing any page subscriptions, but I thought it would
-- be a good idea to put this in here as an example. If I were actually
-- maintaining this in production, I wouldn't bother until I needed this!


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ pageSubscriptions (getPage model.pageState)
        ]


getPage : PageState -> Page
getPage pageState =
    case pageState of
        Loaded page ->
            page

        TransitioningFrom page ->
            page


pageSubscriptions : Page -> Sub Msg
pageSubscriptions page =
    case page of
        Blank ->
            Sub.none

        Errored _ ->
            Sub.none

        NotFound ->
            Sub.none

        Album _ _ ->
            Sub.none

        Photo _ subModel ->
            Sub.map PhotoMsg (Photo.subscriptions subModel)

        Keyword _ _ ->
            Sub.none

        Locations _ _ ->
            Sub.none



-- UPDATE --


type Msg
    = SetRoute (Maybe Route)
    | AlbumLoaded Data.Url.Url (Result PageLoadError Album.Model)
    | AlbumMsg Album.Msg
    | PhotoLoaded Data.Url.Url (Result PageLoadError Photo.Model)
    | PhotoMsg Photo.Msg
    | KeywordLoaded Data.Url.Url (Result PageLoadError Keyword.Model)
    | KeywordMsg Keyword.Msg
    | LocationsLoaded Data.Url.Url (Result PageLoadError Locations.Model)
    | LocationsMsg Locations.Msg


setRoute : Maybe Route -> Model -> ( Model, Cmd Msg )
setRoute maybeRoute model =
    let
        transition toMsg task =
            { model | pageState = TransitioningFrom (getPage model.pageState) }
                => Task.attempt toMsg task
    in
        case maybeRoute of
            Nothing ->
                { model | pageState = Loaded NotFound } => Cmd.none

            Just Route.Root ->
                model => Route.modifyUrl (Route.Album rootUrl)

            -- transition (AlbumLoaded (Data.Url.Url rootUrl)) (Album.init (Data.Url.Url rootUrl))
            Just (Route.Album url) ->
                transition (AlbumLoaded (Data.Url.Url url)) (Album.init (Data.Url.Url url))

            Just (Route.Photo url) ->
                transition (PhotoLoaded (Data.Url.Url url)) (Photo.init (Data.Url.Url url))

            Just (Route.Keyword url) ->
                transition (KeywordLoaded (Data.Url.Url url)) (Keyword.init (Data.Url.Url url))

            Just (Route.Locations url) ->
                transition (LocationsLoaded (Data.Url.Url url)) (Locations.init (Data.Url.Url url))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    updatePage (getPage model.pageState) msg model


updatePage : Page -> Msg -> Model -> ( Model, Cmd Msg )
updatePage page msg model =
    let
        toPage toModel toMsg subUpdate subMsg subModel =
            let
                ( newModel, newCmd ) =
                    subUpdate subMsg subModel
            in
                ( { model | pageState = Loaded (toModel newModel) }, Cmd.map toMsg newCmd )
    in
        case ( msg, page ) of
            ( SetRoute route, _ ) ->
                let
                    ( m, c ) =
                        setRoute route model

                    url =
                        case route of
                            Nothing ->
                                ""

                            Just r ->
                                Route.routeToString r
                in
                    ( m, Cmd.batch [ c, Ports.analytics url ] )

            ( AlbumLoaded url (Ok subModel), _ ) ->
                { model | pageState = Loaded (Album url subModel) } => (Album.initMap subModel)

            ( AlbumLoaded url (Err error), _ ) ->
                { model | pageState = Loaded (Errored error) } => Cmd.none

            ( AlbumMsg subMsg, Album url subModel ) ->
                toPage (Album url) AlbumMsg (Album.update) subMsg subModel

            ( PhotoLoaded url (Ok subModel), _ ) ->
                { model | pageState = Loaded (Photo url subModel) } => (Photo.initMap subModel)

            ( PhotoLoaded url (Err error), _ ) ->
                { model | pageState = Loaded (Errored error) } => Cmd.none

            ( PhotoMsg subMsg, Photo url subModel ) ->
                toPage (Photo url) PhotoMsg (Photo.update) subMsg subModel

            ( KeywordLoaded url (Ok subModel), _ ) ->
                { model | pageState = Loaded (Keyword url subModel) } => (Keyword.initMap subModel)

            ( KeywordLoaded url (Err error), _ ) ->
                { model | pageState = Loaded (Errored error) } => Cmd.none

            ( KeywordMsg subMsg, Keyword url subModel ) ->
                toPage (Keyword url) KeywordMsg (Keyword.update) subMsg subModel

            ( LocationsLoaded url (Ok subModel), _ ) ->
                { model | pageState = Loaded (Locations url subModel) } => Cmd.none

            ( LocationsLoaded url (Err error), _ ) ->
                { model | pageState = Loaded (Errored error) } => Cmd.none

            ( LocationsMsg subMsg, Locations url subModel ) ->
                toPage (Locations url) LocationsMsg (Locations.update) subMsg subModel

            ( _, NotFound ) ->
                -- Disregard incoming messages when we're on the
                -- NotFound page.
                model => Cmd.none

            ( _, _ ) ->
                -- Disregard incoming messages that arrived for the wrong page
                model => Cmd.none



-- MAIN --


main : Program Value Model Msg
main =
    Navigation.programWithFlags (Route.fromLocation >> SetRoute)
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
