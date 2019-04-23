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


json : Parser.Parser (String -> a) a
json =
    Parser.custom "JSON_FILE" <|
        \segment ->
            if String.endsWith ".json" segment then
                Just segment

            else
                Nothing



-- This is stupid, but it works...


rest : Parser.Parser (List String -> a) a
rest =
    --    restHelp 10
    Parser.oneOf
        [ Parser.map (\result -> [ result ]) json
        , Parser.map (\a b -> [ a, b ])
            (Parser.string </> json)
        , Parser.map (\a b c -> [ a, b, c ])
            (Parser.string </> Parser.string </> json)
        , Parser.map (\a b c d -> [ a, b, c, d ])
            (Parser.string </> Parser.string </> Parser.string </> json)
        , Parser.map (\a b c d e -> [ a, b, c, d, e ])
            (Parser.string </> Parser.string </> Parser.string </> Parser.string </> json)
        , Parser.map (\a b c d e f -> [ a, b, c, d, e, f ])
            (Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> json
            )
        , Parser.map (\a b c d e f g -> [ a, b, c, d, e, f, g ])
            (Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> json
            )
        , Parser.map (\a b c d e f g h -> [ a, b, c, d, e, f, g, h ])
            (Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> json
            )
        , Parser.map (\a b c d e f g h i -> [ a, b, c, d, e, f, g, h, i ])
            (Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> json
            )
        , Parser.map (\a b c d e f g h i j -> [ a, b, c, d, e, f, g, h, i, j ])
            (Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> Parser.string
                </> json
            )
        ]



--restHelp : Int -> Parser.Parser (List String -> a) a
--restHelp maxDepth =
--    if maxDepth < 1 then
--        Parser.map [] Parser.top
--
--    else
--        Parser.oneOf
--            [ Parser.map [] Parser.top
--            , Parser.map (\str li -> str :: li) (Parser.string </> restHelp (maxDepth - 1))
--            ]


urlDecoder : Decoder Url
urlDecoder =
    Decode.map Url Decode.string
