open Lwt.Syntax

let filter_collection_helper v =
  let open Yojson.Basic in
  match v with `Assoc _ -> v |> Util.member "items" == `Null | _ -> true

let filter_collection json =
  let open Yojson.Basic in
  Util.to_assoc json |> List.filter (fun (_, v) -> filter_collection_helper v) |> fun x ->
  `Assoc x

let filter_page json =
  let open Yojson.Basic in
  Util.to_assoc json |> List.filter (fun (k, _) -> k <> "items") |> fun x ->
  `Assoc x

let prefer_minimal_container response =
  let open Yojson.Basic in
  let* data = Dream.body response in
  let headers = Dream.all_headers response in
  let status = Dream.status response in
  let json = from_string data in
  let annotations =
    json |> Util.member "type" |> function
    | `String "AnnotationCollection" ->
        let id = json |> Util.member "first" |> Util.member "id" in
        let first = `Assoc [ ("first", id) ] in
        let json' = json |> filter_collection in
        Some (Util.combine json' first)
    | `String "AnnotationPage" -> Some (json |> filter_page)
    | _ -> None
  in
  match annotations with
  | Some annotations -> annotations |> Response.from_json ~status ~headers
  | None ->
      Response.internal_server_error
        "did not find AnnotationCollection or AnnotationPage type"

let prefer_contained_descriptions response = response |> Lwt.return
