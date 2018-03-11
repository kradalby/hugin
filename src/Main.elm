module Main exposing (main)

import Html exposing (..)
import Json.Decode as Decode exposing (Value)
import Navigation exposing (Location)
import Page.Errored as Errored exposing (PageLoadError)
import Page.Home as Home
import Page.Album as Album
import Page.Photo as Photo
import Page.NotFound as NotFound
import Ports
import Route exposing (Route)
import Task
import Util exposing ((=>))
import Views.Page as Page exposing (ActivePage)
import Data.Url
import Request.Helpers exposing (rootUrl)


-- WARNING: Based on discussions around how asset management features
-- like code splitting and lazy loading have been shaping up, I expect
-- most of this file to become unnecessary in a future release of Elm.
-- Avoid putting things in here unless there is no alternative!


type Page
    = Blank
    | NotFound
    | Errored PageLoadError
    | Home Album.Model
    | Album Data.Url.Url Album.Model
    | Photo Data.Url.Url Photo.Model


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

            Errored subModel ->
                Errored.view subModel
                    |> frame Page.Other

            Home subModel ->
                Album.view subModel
                    |> frame (Page.Album (Data.Url.Url rootUrl))
                    |> Html.map AlbumMsg

            Album url subModel ->
                Album.view subModel
                    |> frame (Page.Album url)
                    |> Html.map AlbumMsg

            Photo url subModel ->
                Photo.view subModel
                    |> frame (Page.Photo url)
                    |> Html.map PhotoMsg



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

        Home _ ->
            Sub.none

        Album _ _ ->
            Sub.none

        Photo _ _ ->
            Sub.none



-- UPDATE --


type Msg
    = SetRoute (Maybe Route)
    | HomeLoaded (Result PageLoadError Album.Model)
    | HomeMsg Album.Msg
    | AlbumLoaded Data.Url.Url (Result PageLoadError Album.Model)
    | AlbumMsg Album.Msg
    | PhotoLoaded Data.Url.Url (Result PageLoadError Photo.Model)
    | PhotoMsg Photo.Msg


setRoute : Maybe Route -> Model -> ( Model, Cmd Msg )
setRoute maybeRoute model =
    let
        transition toMsg task =
            { model | pageState = TransitioningFrom (getPage model.pageState) }
                => Task.attempt toMsg task

        errored =
            pageErrored model
    in
        case maybeRoute of
            Nothing ->
                { model | pageState = Loaded NotFound } => Cmd.none

            Just Route.Home ->
                transition HomeLoaded (Album.init (Data.Url.Url rootUrl))

            Just Route.Root ->
                model => Route.modifyUrl Route.Home

            Just (Route.Album url) ->
                transition (AlbumLoaded (Data.Url.Url url)) (Album.init (Data.Url.Url url))

            Just (Route.Photo url) ->
                transition (PhotoLoaded (Data.Url.Url url)) (Photo.init (Data.Url.Url url))


pageErrored : Model -> ActivePage -> String -> ( Model, Cmd msg )
pageErrored model activePage errorMessage =
    let
        error =
            Errored.pageLoadError activePage errorMessage
    in
        { model | pageState = Loaded (Errored error) } => Cmd.none


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

        errored =
            pageErrored model
    in
        case ( msg, page ) of
            ( SetRoute route, _ ) ->
                setRoute route model

            ( HomeLoaded (Ok subModel), _ ) ->
                { model | pageState = Loaded (Home subModel) } => Cmd.none

            ( HomeLoaded (Err error), _ ) ->
                { model | pageState = Loaded (Errored error) } => Cmd.none

            ( HomeMsg subMsg, Home subModel ) ->
                toPage (Album (Data.Url.Url rootUrl)) AlbumMsg (Album.update) subMsg subModel

            ( AlbumLoaded url (Ok subModel), _ ) ->
                { model | pageState = Loaded (Album url subModel) } => Cmd.none

            ( AlbumLoaded url (Err error), _ ) ->
                { model | pageState = Loaded (Errored error) } => Cmd.none

            ( AlbumMsg subMsg, Album url subModel ) ->
                toPage (Album url) AlbumMsg (Album.update) subMsg subModel

            ( PhotoLoaded url (Ok subModel), _ ) ->
                { model | pageState = Loaded (Photo url subModel) } => Cmd.none

            ( PhotoLoaded url (Err error), _ ) ->
                { model | pageState = Loaded (Errored error) } => Cmd.none

            ( PhotoMsg subMsg, Photo url subModel ) ->
                toPage (Photo url) PhotoMsg (Photo.update) subMsg subModel

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
