module RouteTests exposing (suite)

import Expect
import Route
import Test exposing (Test, describe, test)
import Url


{-| Routes carry a bare gallery path (`/album/root/2001/index.json`). The
parser only accepts a final segment ending in `.json`, so anything that
changes how gallery paths are shaped shows up here first.
-}
suite : Test
suite =
    describe "Route"
        [ describe "round-trips through parse and print"
            (List.map roundTrip
                [ Route.Album "root/index.json"
                , Route.Album "root/2001/index.json"
                , Route.Album "root/2018/2018-04-22_Biking_to_Lisse/index.json"
                , Route.SlideShow "root/2001/index.json"
                , Route.Photo "root/2001/2001-01-12.json"
                , Route.Keyword "keywords/Spring.json"
                , Route.Locations "root/locations.json"
                ]
            )
        , describe "route strings"
            [ test "an album route is not prefixed with the content mount" <|
                \_ ->
                    Route.routeToString (Route.Album "root/index.json")
                        |> Expect.equal "#/album/root/index.json"
            , test "a keyword route keeps the keywords prefix" <|
                \_ ->
                    Route.routeToString (Route.Keyword "keywords/Spring.json")
                        |> Expect.equal "#/keyword/keywords/Spring.json"
            ]
        , test "the root route is empty" <|
            \_ ->
                Route.routeToString Route.Root
                    |> Expect.equal "#/"
        ]


roundTrip : Route.Route -> Test
roundTrip route =
    test (Route.routeToString route) <|
        \_ ->
            Route.routeToString route
                |> asUrl
                |> Maybe.andThen Route.fromUrl
                |> Expect.equal (Just route)


{-| `Route.fromUrl` reads the fragment, so a bare fragment string has to be
hung off a host before `Url.fromString` will parse it.
-}
asUrl : String -> Maybe Url.Url
asUrl fragment =
    Url.fromString ("http://localhost" ++ fragment)
