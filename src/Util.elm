module Util exposing
    ( Status(..)
    , cleanOwnerToName
    , formatAltitude
    , formatBytes
    , formatPhotoDate
    , fuzzyKeywordReduce
    , initMap
    , statusToMaybe
    , urlToCssUrl
    , viewIf
    )

import Data.Misc
import Fuzzy
import Html exposing (Html)
import Ports
import Time exposing (Month, Weekday)


viewIf : Bool -> Html msg -> Html msg
viewIf condition content =
    if condition then
        content

    else
        Html.text ""


formatExposureTime : Float -> String
formatExposureTime exposure =
    let
        denominator =
            1 / exposure
    in
    "1/" ++ String.fromFloat denominator


cleanOwnerToName : String -> String
cleanOwnerToName owner =
    let
        keywords =
            [ "Copyright: "
            , "copyright: "
            , "Photograph: "
            , "photograph: "
            , "Copyright"
            , "copyright"
            , "Photograph"
            , "photograph"
            , "photographer:"
            , "Photographer:"
            , "photographer: "
            , "Photographer: "
            ]
    in
    List.foldl (\word acc -> String.replace word "" acc) owner keywords


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


formatAltitude : Float -> String
formatAltitude altitude =
    String.fromInt (round altitude) ++ " meter"


{-| Decimal units, not binary: this sits beside the browser's own readout for
the same transfer, and two numbers that disagree read as a bug.
-}
formatBytes : Int -> String
formatBytes bytes =
    let
        units =
            [ ( 1000000000, "GB" ), ( 1000000, "MB" ), ( 1000, "kB" ) ]

        -- "1.4 GB" is useful, "12.0 MB" is noise.
        round1 value =
            let
                tenths =
                    round (value * 10)
            in
            if modBy 10 tenths == 0 then
                String.fromInt (tenths // 10)

            else
                String.fromInt (tenths // 10) ++ "." ++ String.fromInt (modBy 10 tenths)

        pick remaining =
            case remaining of
                [] ->
                    String.fromInt bytes ++ " bytes"

                ( scale, suffix ) :: smaller ->
                    -- Promote on the ROUNDED value, not the raw one: 999999
                    -- must read "1 MB", never the "1000 kB" nobody writes.
                    if round (toFloat bytes / toFloat scale * 10) >= 10 then
                        round1 (toFloat bytes / toFloat scale) ++ " " ++ suffix

                    else
                        pick smaller
    in
    -- Guarded separately so the rounding rule cannot turn 999 into "1 kB".
    if bytes < 1000 then
        String.fromInt bytes ++ " bytes"

    else
        pick units


formatPhotoDate : Time.Posix -> String
formatPhotoDate date =
    let
        year =
            Time.toYear Time.utc date
                |> String.fromInt

        month =
            Time.toMonth Time.utc date
                |> toMonth

        day =
            Time.toDay Time.utc date
                |> addOrdinalSuffix

        weekday =
            Time.toWeekday Time.utc date
                |> toWeekday

        hour =
            Time.toHour Time.utc date
                |> String.fromInt
                |> String.padLeft 2 '0'

        minute =
            Time.toMinute Time.utc date
                |> String.fromInt
                |> String.padLeft 2 '0'

        second =
            Time.toSecond Time.utc date
                |> String.fromInt
                |> String.padLeft 2 '0'
    in
    weekday
        ++ " "
        ++ day
        ++ " of "
        ++ month
        ++ " "
        ++ year
        ++ " "
        ++ hour
        ++ ":"
        ++ minute
        ++ ":"
        ++ second


toWeekday : Weekday -> String
toWeekday weekday =
    case weekday of
        Time.Mon ->
            "Monday"

        Time.Tue ->
            "Tuesday"

        Time.Wed ->
            "Wednesday"

        Time.Thu ->
            "Thursday"

        Time.Fri ->
            "Friday"

        Time.Sat ->
            "Saturday"

        Time.Sun ->
            "Sunday"


toMonth : Month -> String
toMonth month =
    case month of
        Time.Jan ->
            "January"

        Time.Feb ->
            "February"

        Time.Mar ->
            "March"

        Time.Apr ->
            "April"

        Time.May ->
            "May"

        Time.Jun ->
            "June"

        Time.Jul ->
            "July"

        Time.Aug ->
            "August"

        Time.Sep ->
            "September"

        Time.Oct ->
            "October"

        Time.Nov ->
            "November"

        Time.Dec ->
            "December"


type Status a
    = Loading
    | LoadingSlowly
    | Loaded a
    | Failed


statusToMaybe : Status a -> Maybe a
statusToMaybe status =
    case status of
        Loaded thing ->
            Just thing

        _ ->
            Nothing


addOrdinalSuffix : Int -> String
addOrdinalSuffix number =
    let
        j =
            modBy number 10

        k =
            modBy number 100
    in
    if j == 1 && k /= 11 then
        String.fromInt number ++ "st"

    else if j == 2 && k /= 12 then
        String.fromInt number ++ "nd"

    else if j == 3 && k /= 13 then
        String.fromInt number ++ "rd"

    else
        String.fromInt number ++ "th"


urlToCssUrl : String -> String
urlToCssUrl url =
    let
        characters =
            [ ( " ", "%20" ), ( "'", "%27" ) ]

        escape str chars =
            case chars of
                [] ->
                    str

                ( orig, repl ) :: t ->
                    escape
                        (String.replace orig
                            repl
                            str
                        )
                        t

        escaped =
            escape url characters
    in
    "url(" ++ escaped ++ ")"
