module Util exposing
    ( Status(..)
    , cleanOwnerToName
    , formatExposureTime
    , formatPhotoDate
    , fuzzyKeywordReduce
    , initMap
    , statusToMaybe
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
            [ "Copyright: ", "copyright: ", "Photograph: ", "photograph: ", "Copyright", "copyright", "Photograph", "photograph" ]
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

        minute =
            Time.toMinute Time.utc date
                |> String.fromInt

        second =
            Time.toSecond Time.utc date
                |> String.fromInt
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
