module UtilTests exposing (suite)

import Expect
import Test exposing (Test, describe, test)
import Util


{-| Decimal units because this sits beside the browser's own readout: a tooltip
saying "232 MB" next to a browser saying "243 MB" reads as a bug.
-}
suite : Test
suite =
    describe "Util.formatBytes"
        [ test "bytes below a kilobyte" <|
            \_ ->
                Util.formatBytes 512
                    |> Expect.equal "512 bytes"
        , test "zero" <|
            \_ ->
                Util.formatBytes 0
                    |> Expect.equal "0 bytes"
        , test "kilobytes" <|
            \_ ->
                Util.formatBytes 42653
                    |> Expect.equal "42.7 kB"
        , test "megabytes" <|
            \_ ->
                Util.formatBytes 243100000
                    |> Expect.equal "243.1 MB"
        , test "gigabytes" <|
            \_ ->
                Util.formatBytes 4294967296
                    |> Expect.equal "4.3 GB"
        , test "drops a zero decimal" <|
            \_ ->
                Util.formatBytes 12000000
                    |> Expect.equal "12 MB"
        , -- The unit is chosen from the ROUNDED value, so 999999 reads "1 MB"
          -- rather than the "1000 kB" nobody writes.
          test "rounding up promotes to the larger unit" <|
            \_ ->
                [ Util.formatBytes 999
                , Util.formatBytes 1000
                , Util.formatBytes 999999
                , Util.formatBytes 1000000
                , Util.formatBytes 999999999
                ]
                    |> Expect.equal [ "999 bytes", "1 kB", "1 MB", "1 MB", "1 GB" ]
        , test "negative input does not crash" <|
            \_ ->
                Util.formatBytes -1
                    |> Expect.equal "-1 bytes"
        ]
