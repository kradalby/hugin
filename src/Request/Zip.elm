module Request.Zip exposing (Archive, available, fromResponse)

{-| Hugin is also served as plain static files, where there is no /zip endpoint
and the button must not appear. One HEAD settles both whether it exists and how
big the archive would be.
-}

import Data.Url as Url exposing (Url)
import Dict
import Http


{-| `size` is only a tooltip nicety, kept separate from the capability so a
proxy dropping `Content-Length` cannot remove a working feature.
-}
type alias Archive =
    { size : Maybe Int }


{-| Checks the content type, not just the status: a static SPA fallback answers
200 text/html for any path, giving a button that downloads index.html as `.zip`.
-}
available : Url -> (Result Http.Error (Maybe Archive) -> msg) -> Cmd msg
available url msg =
    Http.request
        { method = "HEAD"
        , headers = []
        , url = Url.toZipUrl url
        , body = Http.emptyBody
        , expect = Http.expectStringResponse msg fromResponse
        , timeout = Nothing
        , tracker = Nothing
        }


{-| A 404 is an ordinary answer; a timeout or network error is not, and every
sibling request logs those.
-}
fromResponse : Http.Response String -> Result Http.Error (Maybe Archive)
fromResponse response =
    case response of
        Http.GoodStatus_ metadata _ ->
            Ok (archiveFrom metadata)

        Http.BadStatus_ _ _ ->
            Ok Nothing

        Http.BadUrl_ url ->
            Err (Http.BadUrl url)

        Http.Timeout_ ->
            Err Http.Timeout

        Http.NetworkError_ ->
            Err Http.NetworkError


archiveFrom : Http.Metadata -> Maybe Archive
archiveFrom metadata =
    let
        -- Lowercased by the browser per the XHR spec, not by Elm: elm/http
        -- inserts header names verbatim.
        header name =
            Dict.get (String.toLower name) metadata.headers

        -- A proxy may append a parameter, so match the type, not the string.
        isArchive =
            header "content-type"
                |> Maybe.map (String.trim >> String.toLower)
                |> Maybe.map (String.startsWith "application/zip")
                |> Maybe.withDefault False

        positive n =
            if n > 0 then
                Just n

            else
                Nothing
    in
    if isArchive then
        Just
            { size =
                header "content-length"
                    |> Maybe.andThen String.toInt
                    |> Maybe.andThen positive
            }

    else
        Nothing
