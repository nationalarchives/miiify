
let validate_uri_scheme uri =
  Uri.scheme uri |> function
  | Some scheme when scheme = "https" -> true
  | _ -> false

let validate_uri_host uri =
  Uri.host uri |> function
  | Some _ -> true
  | None -> false

let validate_uri x =
  let uri = Uri.of_string x in
  validate_uri_scheme uri && validate_uri_host uri

let validate_id x =
  match x with
  | Some x -> validate_uri x
  | None -> true
  
let validate_target = validate_uri

let validate_value x = String.is_valid_utf_8 x

