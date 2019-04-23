module Main exposing (main)

import Browser exposing (Document)
import Browser.Navigation as Nav
import Data.Url
import Html
import Json.Decode as Decode exposing (Value)
import Page
import Page.Album as Album
import Page.Blank as Blank
import Page.Keyword as Keyword
import Page.Locations as Locations
import Page.NotFound as NotFound
import Page.Photo as Photo
import Ports
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
init _ url navKey =
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

        Album url m ->
            viewPage (Page.Album url) GotAlbumMsg (Album.view m)

        Photo url m ->
            viewPage (Page.Photo url) GotPhotoMsg (Photo.view m)

        Keyword url m ->
            viewPage (Page.Keyword url) GotKeywordMsg (Keyword.view m)

        Locations url m ->
            viewPage (Page.Locations url) GotLocationsMsg (Locations.view m)



-- SUBSCRIPTIONS --


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
    | ChangedUrl Url
    | ClickedLink Browser.UrlRequest
    | GotAlbumMsg Album.Msg
    | GotPhotoMsg Photo.Msg
    | GotKeywordMsg Keyword.Msg
    | GotLocationsMsg Locations.Msg


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


changeRouteTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeRouteTo maybeRoute model =
    let
        session =
            toSession model

        analyticsUrl =
            case maybeRoute of
                Nothing ->
                    ""

                Just route ->
                    Route.routeToString route

        ( m, c ) =
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
    in
    ( m, Cmd.batch [ c, Ports.analytics analyticsUrl ] )


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
                            ( model, Cmd.none )

                        Just _ ->
                            ( model
                            , Nav.pushUrl (Session.navKey (toSession model)) (Url.toString url)
                            )

                Browser.External href ->
                    ( model
                    , Nav.load href
                    )

        ( ChangedUrl url, _ ) ->
            changeRouteTo (Route.fromUrl url) model

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
updateWith toModel toMsg _ ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )


main : Program Decode.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = ChangedUrl
        , onUrlRequest = ClickedLink
        }
