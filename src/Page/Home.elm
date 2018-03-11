module Page.Home exposing (Model, Msg, init, update, view)

{-| The homepage. You can get here via either the / or /#/ routes.
-}

import Data.Album as Album exposing (Album)
import Data.Photo as Photo exposing (Photo)
import Data.Url as Url exposing (Url)
import Html exposing (..)
import Html.Attributes exposing (attribute, class, classList, href, id, placeholder)
import Html.Events exposing (onClick)
import Http
import Page.Errored exposing (PageLoadError, pageLoadError)
import Request.Album
import Request.Photo
import Task exposing (Task)
import Util exposing ((=>), onClickStopPropagation)
import Views.Page as Page


-- MODEL --


type alias Model =
    --    { errors : List String
    --    , album : Album
    --    }
    {}


init : Task PageLoadError Model
init =
    let
        -- url =
        --     Url "/out/krapic/index.json"
        -- loadAlbum =
        --     Request.Album.get url
        --         |> Http.toTask
        handleLoadError _ =
            pageLoadError Page.Home "Homepage is currently unavailable."
    in
        -- Task.map Model loadAlbum
        --     |> Task.mapError handleLoadError
        Task.succeed Model |> Task.mapError handleLoadError



-- VIEW --


view : Model -> Html Msg
view model =
    --    let
    --        album =
    --            model.album
    --    in
    div [ class "home-page" ]
        [ div [ class "container page" ]
            [ div [ class "row" ]
                [ div [ class "col-md-9" ] []
                , div [ class "col-md-3" ]
                    [ div [ class "sidebar" ] []

                    --                           [ p [] [ text (toString album) ] ]
                    ]
                ]
            ]
        ]



-- UPDATE --


type Msg
    = Noop


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Noop ->
            model => Cmd.none



-- type Msg
--     = FeedMsg Feed.Msg
--     | SelectTag Tag
--
--
-- update : Msg -> Model -> ( Model, Cmd Msg )
-- update msg model =
--     case msg of
--         FeedMsg subMsg ->
--             let
--                 ( newFeed, subCmd ) =
--                     Feed.update session subMsg model.feed
--             in
--                 { model | feed = newFeed } => Cmd.map FeedMsg subCmd
