module Views.Assets exposing (error, loading, notFound, placeholder, src)

{-| Assets, such as images, videos, and audio. (We only have images for now.)

We should never expose asset URLs directly; this module should be in charge of
all of them. One source of truth!

-}

import Html exposing (Attribute, Html)
import Html.Attributes as Attr


type Image
    = Image String



-- IMAGES --


error : Image
error =
    Image "/images/error.jpg"


placeholder : Image
placeholder =
    Image "/images/placeholder.png"


notFound : Image
notFound =
    Image "/images/404.jpg"


loading : Image
loading =
    Image "/images/loading.svg"



-- USING IMAGES --


src : Image -> Attribute msg
src (Image url) =
    Attr.src url
