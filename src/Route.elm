module Route exposing (Route(..), fromUrl, href, parser, pushUrl, replaceUrl)

import Browser.Navigation as Nav
import Data.Url as HuginUrl
import Html exposing (Attribute)
import Html.Attributes as Attr
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), Parser, oneOf, s, string)



-- ROUTING --


type Route
    = Root
    | Album String
    | Photo String
    | Keyword String
    | Locations String


parser : Parser (Route -> a) a
parser =
    oneOf
        [ Parser.map Root Parser.top
        , Parser.map (Album << String.join "/") (s "album" </> HuginUrl.rest)
        , Parser.map (Photo << String.join "/") (s "photo" </> HuginUrl.rest)
        , Parser.map (Keyword << String.join "/") (s "keyword" </> HuginUrl.rest)
        , Parser.map (Locations << String.join "/") (s "locations" </> HuginUrl.rest)
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
href targetRoute =
    Attr.href (routeToString targetRoute)


pushUrl : Nav.Key -> Route -> Cmd msg
pushUrl key route =
    Nav.pushUrl key (routeToString route)


replaceUrl : Nav.Key -> Route -> Cmd msg
replaceUrl key route =
    Nav.replaceUrl key (routeToString route)


fromUrl : Url -> Maybe Route
fromUrl url =
    { url | path = Maybe.withDefault "" url.fragment, fragment = Nothing }
        |> Parser.parse parser



--fromLocation : Location -> Maybe Route
--fromLocation location =
--    if String.isEmpty location.hash then
--        Just Root
--
--    else
--        parseHash route location
