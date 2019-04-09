module Session exposing (Session, navKey)

import Browser.Navigation as Nav


type alias Session =
    Nav.Key


navKey : Session -> Nav.Key
navKey session =
    session
