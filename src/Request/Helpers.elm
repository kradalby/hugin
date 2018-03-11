module Request.Helpers exposing (rootUrl, apiUrl)


rootUrl : String
rootUrl =
    "out/krapic/index.json"


apiUrl : String -> String
apiUrl str =
    "/" ++ str
