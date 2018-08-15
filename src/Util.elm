module Util exposing ((=>), appendErrors, onClickStopPropagation, pair, viewIf, traceDecoder, formatExposureTime, cleanOwnerToName, initMap, fuzzyKeywordReduce)

import Html exposing (Attribute, Html)
import Html.Events exposing (defaultOptions, onWithOptions)
import Json.Decode as Decode
import String.Extra
import Data.Misc
import Ports
import Fuzzy


(=>) : a -> b -> ( a, b )
(=>) =
    (,)


{-| infixl 0 means the (=>) operator has the same precedence as (<|) and (|>),
meaning you can use it at the end of a pipeline and have the precedence work out.
-}
infixl 0 =>


{-| Useful when building up a Cmd via a pipeline, and then pairing it with
a model at the end.

    session.user
        |> User.Request.foo
        |> Task.attempt Foo
        |> pair { model | something = blah }

-}
pair : a -> b -> ( a, b )
pair first second =
    first => second


viewIf : Bool -> Html msg -> Html msg
viewIf condition content =
    if condition then
        content
    else
        Html.text ""


onClickStopPropagation : msg -> Attribute msg
onClickStopPropagation msg =
    onWithOptions "click"
        { defaultOptions | stopPropagation = True }
        (Decode.succeed msg)


appendErrors : { model | errors : List error } -> List error -> { model | errors : List error }
appendErrors model errors =
    { model | errors = model.errors ++ errors }


traceDecoder : String -> Decode.Decoder msg -> Decode.Decoder msg
traceDecoder message decoder =
    Decode.value
        |> Decode.andThen
            (\value ->
                case Decode.decodeValue decoder value of
                    Ok decoded ->
                        -- Decode.succeed <| Debug.log ("Success: " ++ message) <| decoded
                        Decode.succeed decoded

                    Err err ->
                        Decode.fail <| Debug.log ("Fail: " ++ message) <| err
            )


formatExposureTime : Float -> String
formatExposureTime exposure =
    let
        denominator =
            1 / exposure
    in
        "1/" ++ (toString denominator)


cleanOwnerToName : String -> String
cleanOwnerToName owner =
    let
        keywords =
            [ "Copyright: ", "copyright: ", "Photograph: ", "photograph: ", "Copyright", "copyright", "Photograph", "photograph" ]
    in
        List.foldl (\word acc -> String.Extra.replace word "" acc) owner keywords


initMap : String -> List Data.Misc.GPS -> Cmd msg
initMap name coordinates =
    let
        gpsToLongLat gps =
            ( gps.longitude, gps.latitude )

        longLats =
            List.map gpsToLongLat coordinates
    in
        case longLats of
            [] ->
                Cmd.none

            _ ->
                Ports.initMap ( name, longLats )


fuzzyKeywordReduce : String -> List Data.Misc.KeywordPointer -> List Data.Misc.KeywordPointer
fuzzyKeywordReduce searchString keywordPointers =
    case searchString of
        "" ->
            List.sortBy .name keywordPointers

        _ ->
            let
                isValid kwp =
                    (match << keyword) kwp < 2000

                keyword kwp =
                    kwp.name

                match input =
                    Fuzzy.match []
                        []
                        (String.toLower searchString)
                        (String.toLower input)
                        |> .score

                filteredPointers =
                    List.filter
                        isValid
                        keywordPointers
            in
                List.sortBy (match << keyword) filteredPointers
