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
    Image "/placeholder.fe8e4556.png"


notFound : Image
notFound =
    Image "/404.f70fed75.jpg"


loading : Image
loading =
    Image "/loading.fb790484.svg"



-- USING IMAGES --


src : Image -> Attribute msg
src (Image url) =
    Attr.src url
