module Main exposing (main)

-- import Navigation exposing (Location)

import Browser exposing (Document)
import Browser.Navigation as Nav
import Data.Url
import Html exposing (..)
import Json.Decode as Decode exposing (Value)
import Page exposing (Page)
import Page.Album as Album
import Page.Blank as Blank
import Page.Keyword as Keyword
import Page.Locations as Locations
import Page.NotFound as NotFound
import Page.Photo as Photo
import Request.Helpers exposing (rootUrl)
import Route exposing (Route)
import Session exposing (Session)
import Url exposing (Url)


type Model
    = Redirect Session
    | NotFound Session
    | Album Data.Url.Url Album.Model
    | Photo Data.Url.Url Photo.Model
    | Keyword Data.Url.Url Keyword.Model
    | Locations Data.Url.Url Locations.Model


init : Value -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url navKey =
    changeRouteTo (Route.fromUrl url)
        (Redirect navKey)



-- VIEW --


view : Model -> Document Msg
view model =
    let
        viewPage page toMsg config =
            let
                { title, body } =
                    Page.view page config
            in
            { title = title
            , body = List.map (Html.map toMsg) body
            }
    in
    case model of
        Redirect _ ->
            viewPage Page.Other (\_ -> Ignored) Blank.view

        NotFound _ ->
            viewPage Page.Other (\_ -> Ignored) NotFound.view

        --        Settings settings ->
        --            viewPage Page.Other GotSettingsMsg (Settings.view settings)
        Album url m ->
            viewPage (Page.Album url) GotAlbumMsg (Album.view m)

        Photo url m ->
            viewPage (Page.Photo url) GotPhotoMsg (Photo.view m)

        Keyword url m ->
            viewPage (Page.Keyword url) GotKeywordMsg (Keyword.view m)

        Locations url m ->
            viewPage (Page.Locations url) GotLocationsMsg (Locations.view m)



-- SUBSCRIPTIONS --
-- Note: we aren't currently doing any page subscriptions, but I thought it would
-- be a good idea to put this in here as an example. If I were actually
-- maintaining this in production, I wouldn't bother until I needed this!
-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        NotFound _ ->
            Sub.none

        --        Redirect _ ->
        --            Session.changes GotSession (Session.navKey (toSession model))
        Album _ m ->
            Sub.map GotAlbumMsg (Album.subscriptions m)

        Photo _ m ->
            Sub.map GotPhotoMsg (Photo.subscriptions m)

        Keyword _ m ->
            Sub.map GotKeywordMsg (Keyword.subscriptions m)

        Locations _ m ->
            Sub.map GotLocationsMsg (Locations.subscriptions m)

        Redirect _ ->
            Sub.none



-- UPDATE --


type Msg
    = Ignored
    | ChangedRoute (Maybe Route)
    | ChangedUrl Url
    | ClickedLink Browser.UrlRequest
    | GotAlbumMsg Album.Msg
    | GotPhotoMsg Photo.Msg
    | GotKeywordMsg Keyword.Msg
    | GotLocationsMsg Locations.Msg



--setRoute : Maybe Route -> Model -> ( Model, Cmd Msg )
--setRoute maybeRoute model =
--    let
--        transition toMsg task =
--            { model | pageState = TransitioningFrom (getPage model.pageState) }
--                => Task.attempt toMsg task
--    in
--    case maybeRoute of
--        Nothing ->
--            { model | pageState = Loaded NotFound } => Cmd.none
--
--        Just Route.Root ->
--            model => Route.modifyUrl (Route.Album rootUrl)
--
--        -- transition (AlbumLoaded (Data.Url.Url rootUrl)) (Album.init (Data.Url.Url rootUrl))
--        Just (Route.Album url) ->
--            transition (AlbumLoaded (Data.Url.Url url)) (Album.init (Data.Url.Url url))
--
--        Just (Route.Photo url) ->
--            transition (PhotoLoaded (Data.Url.Url url)) (Photo.init (Data.Url.Url url))
--
--        Just (Route.Keyword url) ->
--            transition (KeywordLoaded (Data.Url.Url url)) (Keyword.init (Data.Url.Url url))
--
--        Just (Route.Locations url) ->
--            transition (LocationsLoaded (Data.Url.Url url)) (Locations.init (Data.Url.Url url))


toSession : Model -> Session
toSession page =
    case page of
        NotFound session ->
            session

        Album _ model ->
            Album.toSession model

        Photo _ model ->
            Photo.toSession model

        Keyword _ model ->
            Keyword.toSession model

        Locations _ model ->
            Locations.toSession model

        Redirect session ->
            session



-- TODO: Remember analytics!


changeRouteTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeRouteTo maybeRoute model =
    let
        session =
            toSession model
    in
    case maybeRoute of
        Nothing ->
            ( NotFound session, Cmd.none )

        Just Route.Root ->
            ( model, Route.replaceUrl (Session.navKey session) (Route.Album rootUrl) )

        Just (Route.Album urlString) ->
            let
                url =
                    Data.Url.fromString urlString
            in
            Album.init session url
                |> updateWith (Album url) GotAlbumMsg model

        Just (Route.Photo urlString) ->
            let
                url =
                    Data.Url.fromString urlString
            in
            Photo.init session url
                |> updateWith (Photo url) GotPhotoMsg model

        Just (Route.Keyword urlString) ->
            let
                url =
                    Data.Url.fromString urlString
            in
            Keyword.init session url
                |> updateWith (Keyword url) GotKeywordMsg model

        Just (Route.Locations urlString) ->
            let
                url =
                    Data.Url.fromString urlString
            in
            Locations.init session url
                |> updateWith (Locations url) GotLocationsMsg model


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( Ignored, _ ) ->
            ( model, Cmd.none )

        ( ClickedLink urlRequest, _ ) ->
            case urlRequest of
                Browser.Internal url ->
                    case url.fragment of
                        Nothing ->
                            let
                                derp =
                                    Debug.log "url nothing" url
                            in
                            ( model, Cmd.none )

                        Just _ ->
                            let
                                derp =
                                    Debug.log "url just" url
                            in
                            ( model
                            , Nav.pushUrl (Session.navKey (toSession model)) (Url.toString url)
                            )

                Browser.External href ->
                    ( model
                    , Nav.load href
                    )

        ( ChangedUrl url, _ ) ->
            changeRouteTo (Route.fromUrl url) model

        ( ChangedRoute route, _ ) ->
            changeRouteTo route model

        ( GotAlbumMsg subMsg, Album url m ) ->
            Album.update subMsg m
                |> updateWith (Album url) GotAlbumMsg model

        ( GotPhotoMsg subMsg, Photo url m ) ->
            Photo.update subMsg m
                |> updateWith (Photo url) GotPhotoMsg model

        ( GotKeywordMsg subMsg, Keyword url m ) ->
            Keyword.update subMsg m
                |> updateWith (Keyword url) GotKeywordMsg model

        ( GotLocationsMsg subMsg, Locations url m ) ->
            Locations.update subMsg m
                |> updateWith (Locations url) GotLocationsMsg model

        ( _, _ ) ->
            -- Disregard messages that arrived for the wrong page.
            ( model, Cmd.none )


updateWith : (subModel -> Model) -> (subMsg -> Msg) -> Model -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toModel toMsg model ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )



--update : Msg -> Model -> ( Model, Cmd Msg )
--update msg model =
--    updatePage (getPage model.pageState) msg model
--
--
--updatePage : Page -> Msg -> Model -> ( Model, Cmd Msg )
--updatePage page msg model =
--    let
--        toPage toModel toMsg subUpdate subMsg subModel =
--            let
--                ( newModel, newCmd ) =
--                    subUpdate subMsg subModel
--            in
--            ( { model | pageState = Loaded (toModel newModel) }, Cmd.map toMsg newCmd )
--    in
--    case ( msg, page ) of
--        ( SetRoute route, _ ) ->
--            let
--                ( m, c ) =
--                    setRoute route model
--
--                url =
--                    case route of
--                        Nothing ->
--                            ""
--
--                        Just r ->
--                            Route.routeToString r
--            in
--            ( m, Cmd.batch [ c, Ports.analytics url ] )
--
--        ( ClickedLink urlRequest, _ ) ->
--            case urlRequest of
--                Browser.Internal url ->
--                    case url.fragment of
--                        Nothing ->
--                            -- If we got a link that didn't include a fragment,
--                            -- it's from one of those (href "") attributes that
--                            -- we have to include to make the RealWorld CSS work.
--                            --
--                            -- In an application doing path routing instead of
--                            -- fragment-based routing, this entire
--                            -- `case url.fragment of` expression this comment
--                            -- is inside would be unnecessary.
--                            ( model, Cmd.none )
--
--                        Just _ ->
--                            ( model
--                            , Nav.pushUrl (Session.navKey (toSession model)) (Url.toString url)
--                            )
--
--                Browser.External href ->
--                    ( model
--                    , Nav.load href
--                    )
--
--        ( ChangedUrl url, _ ) ->
--            changeRouteTo (Route.fromUrl url) model
--
--        ( AlbumLoaded url (Ok subModel), _ ) ->
--            { model | pageState = Loaded (Album url subModel) } => Album.initMap subModel
--
--        ( AlbumLoaded url (Err error), _ ) ->
--            { model | pageState = Loaded (Errored error) } => Cmd.none
--
--        ( AlbumMsg subMsg, Album url subModel ) ->
--            toPage (Album url) AlbumMsg Album.update subMsg subModel
--
--        ( PhotoLoaded url (Ok subModel), _ ) ->
--            { model | pageState = Loaded (Photo url subModel) } => Photo.initMap subModel
--
--        ( PhotoLoaded url (Err error), _ ) ->
--            { model | pageState = Loaded (Errored error) } => Cmd.none
--
--        ( PhotoMsg subMsg, Photo url subModel ) ->
--            toPage (Photo url) PhotoMsg Photo.update subMsg subModel
--
--        ( KeywordLoaded url (Ok subModel), _ ) ->
--            { model | pageState = Loaded (Keyword url subModel) } => Keyword.initMap subModel
--
--        ( KeywordLoaded url (Err error), _ ) ->
--            { model | pageState = Loaded (Errored error) } => Cmd.none
--
--        ( KeywordMsg subMsg, Keyword url subModel ) ->
--            toPage (Keyword url) KeywordMsg Keyword.update subMsg subModel
--
--        ( LocationsLoaded url (Ok subModel), _ ) ->
--            { model | pageState = Loaded (Locations url subModel) } => Cmd.none
--
--        ( LocationsLoaded url (Err error), _ ) ->
--            { model | pageState = Loaded (Errored error) } => Cmd.none
--
--        ( LocationsMsg subMsg, Locations url subModel ) ->
--            toPage (Locations url) LocationsMsg Locations.update subMsg subModel
--
--        ( _, NotFound ) ->
--            -- Disregard incoming messages when we're on the
--            -- NotFound page.
--            model => Cmd.none
--
--        ( _, _ ) ->
--            -- Disregard incoming messages that arrived for the wrong page
--            model => Cmd.none
-- MAIN --


main : Program Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = ChangedUrl
        , onUrlRequest = ClickedLink
        }



--    Navigation.programWithFlags (Route.fromLocation >> SetRoute)
--        { init = init
--        , view = view
--        , update = update
--        , subscriptions = subscriptions
--        }
