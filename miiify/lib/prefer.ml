open Lwt.Syntax

let filter_collection_helper v =
  let open Yojson.Basic.Util in
  match v with `Assoc _ -> v |> member "items" == `Null | _ -> true

let filter_collection json =
  let open Yojson.Basic.Util in
  to_assoc json |> List.filter (fun (_, v) -> filter_collection_helper v)
  |> fun x -> `Assoc x

let filter_page json =
  let open Yojson.Basic.Util in
  to_assoc json |> List.filter (fun (k, _) -> k <> "items") |> fun x -> `Assoc x

let send ~status ~headers annotations =
  match annotations with
  | Some annotations -> Response.from_json ~status ~headers annotations
  | None ->
      Response.internal_server_error
        "did not find AnnotationCollection or AnnotationPage type"

let prefer_minimal_container response =
  Dream.header response "Content-Type" |> function
  | Some header when header = Dream.text_html ->
      response |> Lwt.return
  | _ ->
      let open Yojson.Basic.Util in
      let* data = Dream.body response in
      let headers = Dream.all_headers response in
      let status = Dream.status response in
      let json = Yojson.Basic.from_string data in
      let annotations =
        json |> member "type" |> function
        | `String "AnnotationCollection" ->
            let id = json |> member "first" |> member "id" in
            let first = `Assoc [ ("first", id) ] in
            let json' = json |> filter_collection in
            Some (combine json' first)
        | `String "AnnotationPage" -> Some (json |> filter_page)
        | _ -> None
      in
      send ~status ~headers annotations

let get_iris items =
  let open Yojson.Basic.Util in
  to_list items |> List.map (fun x -> x |> member "id") |> fun x -> `List x

let first json items =
  let open Yojson.Basic.Util in
  let type_ = json |> member "type" in
  let next = json |> member "next" in
  `Assoc [ ("type", type_); ("items", items); ("next", next) ]
  |> Utils.Json.filter_null

let prefer_contained_iris response =
  Dream.header response "Content-Type" |> function
  | Some header when header = Dream.text_html ->
      response |> Lwt.return
  | _ ->
      let open Yojson.Basic.Util in
      let* data = Dream.body response in
      let headers = Dream.all_headers response in
      let status = Dream.status response in
      let json = Yojson.Basic.from_string data in
      let annotations =
        json |> member "type" |> function
        | `String "AnnotationCollection" ->
            let json' = json |> filter_collection in
            let items = json |> member "first" |> member "items" in
            let iris = get_iris items in
            let first = `Assoc [ ("first", first json iris) ] in
            Some (combine json' first)
        | `String "AnnotationPage" ->
            let json' = json |> filter_page in
            let items = json |> member "items" in
            let iris = get_iris items in
            let items = `Assoc [ ("items", iris) ] in
            Some (combine json' items)
        | _ -> None
      in
      send ~status ~headers annotations

let prefer_contained_descriptions response = response |> Lwt.return
