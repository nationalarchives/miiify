open Yojson.Basic

let is_manifest json =
  match json |> Util.member "type" with
  | `String "Manifest" -> true
  | _ -> false

let create ~data =
  match from_string data with
  | exception Yojson.Json_error m -> Result.error m
  | json ->
      if is_manifest json then Result.ok json
      else Result.error "manifest type not found"

let update ~data = create ~data
let manifest json = json |> to_string
