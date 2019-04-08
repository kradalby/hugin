module Data.Url exposing (Url(..), encodeUrl, rest, urlDecoder, urlToHtml, urlToString)

import Html exposing (Html)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import UrlParser exposing ((</>))


type Url
    = Url String


urlToString : Url -> String
urlToString (Url url) =
    url



-- urlParser : UrlParser.Parser (Url -> a) a
-- urlParser =
--     UrlParser.custom "URL" <|
--         \segment ->
--             let
--                 derp =
--                     Debug.log "segment" segment
--             in
--                 if String.endsWith ".json" segment then
--                     Ok (Url segment)
--                 else
--                     Err "Does not end with .json"


rest : UrlParser.Parser (List String -> a) a
rest =
    restHelp 10


restHelp : Int -> UrlParser.Parser (List String -> a) a
restHelp maxDepth =
    if maxDepth < 1 then
        UrlParser.map [] UrlParser.top

    else
        UrlParser.oneOf
            [ UrlParser.map [] UrlParser.top
            , UrlParser.map (::) (UrlParser.string </> restHelp (maxDepth - 1))
            ]


urlDecoder : Decoder Url
urlDecoder =
    Decode.map Url Decode.string


encodeUrl : Url -> Value
encodeUrl (Url url) =
    Encode.string url


urlToHtml : Url -> Html msg
urlToHtml (Url url) =
    Html.text url
