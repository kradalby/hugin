module Route exposing (Route(..), fromLocation, href, modifyUrl)

import Html exposing (Attribute)
import Html.Attributes as Attr
import Navigation exposing (Location)
import UrlParser exposing ((</>), Parser, oneOf, parseHash, s, string)
import Data.Url as Url exposing (Url)


-- ROUTING --


type Route
    = Root
    | Album String
    | Photo String
    | Keyword String
    | Locations String


route : Parser (Route -> a) a
route =
    oneOf
        [ UrlParser.map Root (s "")
        , UrlParser.map (Album << String.join "/") (s "album" </> Url.rest)
        , UrlParser.map (Photo << String.join "/") (s "photo" </> Url.rest)
        , UrlParser.map (Keyword << String.join "/") (s "keyword" </> Url.rest)
        , UrlParser.map (Locations << String.join "/") (s "locations" </> Url.rest)
        ]



-- INTERNAL --


routeToString : Route -> String
routeToString page =
    let
        pieces =
            case page of
                Root ->
                    []

                Album url ->
                    [ "album", url ]

                Photo url ->
                    [ "photo", url ]

                Keyword url ->
                    [ "keyword", url ]

                Locations url ->
                    [ "locations", url ]
    in
        "#/" ++ String.join "/" pieces



-- PUBLIC HELPERS --


href : Route -> Attribute msg
href route =
    Attr.href (routeToString route)


modifyUrl : Route -> Cmd msg
modifyUrl =
    routeToString >> Navigation.modifyUrl


fromLocation : Location -> Maybe Route
fromLocation location =
    if String.isEmpty location.hash then
        Just Root
    else
        parseHash route location
