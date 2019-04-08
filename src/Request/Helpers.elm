module Request.Helpers exposing (apiUrl, rootUrl)


rootUrl : String
rootUrl =
    "content/root/index.json"


apiUrl : String -> String
apiUrl str =
    "/" ++ str
