module Data.Url exposing (Url(..), fromString, rest, urlDecoder, urlToString)

import Json.Decode as Decode exposing (Decoder)
import Url.Parser as Parser exposing ((</>))


type Url
    = Url String


urlToString : Url -> String
urlToString (Url url) =
    url


fromString : String -> Url
fromString str =
    Url str



-- This works, but I must admit that its a bit over my head...


rest : Parser.Parser (List String -> a) a
rest =
    restHelp 10


restHelp : Int -> Parser.Parser (List String -> a) a
restHelp maxDepth =
    if maxDepth < 1 then
        Parser.map [] Parser.top

    else
        Parser.oneOf
            [ Parser.map [] Parser.top

            --            , Parser.map (::) (Parser.string </> restHelp (maxDepth - 1))
            ]


urlDecoder : Decoder Url
urlDecoder =
    Decode.map Url Decode.string



--
--encodeUrl : Url -> Value
--encodeUrl (Url url) =
--    Encode.string url
--
--
--urlToHtml : Url -> Html msg
--urlToHtml (Url url) =
--    Html.text url
