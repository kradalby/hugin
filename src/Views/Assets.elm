module Views.Assets exposing (loading, notFound, placeholder, src)

import Html exposing (Attribute)
import Html.Attributes as Attr


type Image
    = Image String



-- IMAGES --
-- error : Image
-- error =
--     Image "/error.jpg"


placeholder : Image
placeholder =
    Image "/placeholder.png"


notFound : Image
notFound =
    Image "/404.jpg"


loading : Image
loading =
    Image "/loading.svg"



-- USING IMAGES --


src : Image -> Attribute msg
src (Image url) =
    Attr.src url
