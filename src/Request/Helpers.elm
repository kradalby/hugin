module Request.Helpers exposing (rootUrl, apiUrl)


rootUrl : String
rootUrl =
    "content/root/index.json"


apiUrl : String -> String
apiUrl str =
    "/" ++ str
