open Yojson.Basic

let annotation_page_id json =
  let open Utils in
  let id = json |> Util.member "id" in
  let params = Json.id_helper 0 in
  id |> function `String x -> `String (x ^ params) | _ -> `Null

let last json total limit =
  let open Utils in
  let last_page = Math.calculate_page total limit in
  if last_page > 0 then
    let id = json |> Util.member "id" in
    let params = Json.id_helper last_page in
    id |> function `String x -> `String (x ^ params) | _ -> `Null
  else `Null

let next json page total limit =
  let open Utils in
  let id = json |> Util.member "id" in
  let last_page = Math.calculate_page total limit in
  if page < last_page then
    let next = Json.id_helper (page + 1) in
    id |> function `String x -> `String (x ^ next) | _ -> `Null
  else `Null

let first json page total limit =
  let open Util in
  let id = annotation_page_id json in
  let items = json |> member "items" in
  let next = next json page total limit in
  `Assoc
    [
      ("id", id);
      ("type", `String "AnnotationPage");
      ("items", items);
      ("next", next);
    ]
  |> Utils.Json.filter_null

let collection_worker json page total limit =
  let open Util in
  let id = json |> member "id" in
  let type_ = json |> member "type" in
  let first = first json page total limit in
  let last = last json total limit in
  let total = total |> function 0 -> `Null | _ -> `Int total in
  let context = json |> member "@context" in
  let label = json |> member "label" in
  let created = json |> member "created" in
  let modified = json |> member "modified" in
  `Assoc
    [
      ("@context", context);
      ("id", id);
      ("type", type_);
      ("label", label);
      ("created", created);
      ("modified", modified);
      ("total", total);
      ("first", first);
      ("last", last);
    ]
  |> Utils.Json.filter_null

let collection json ~total ~limit =
  collection_worker json 0 total limit |> to_string

let container json = json |> to_string

(* Inject ID into container for read-only serving *)
let inject_id json ~container_id ~base_url =
  let open Util in
  let existing_id = json |> member "id" in
  match existing_id with
  | `Null ->
      (* No ID present, inject it *)
      let iri = base_url ^ "/" ^ container_id ^ "/" in
      combine (`Assoc [ ("id", `String iri) ]) json
  | `String id ->
      (* ID exists but might not match server URL, update it *)
      let iri = base_url ^ "/" ^ container_id ^ "/" in
      if id <> iri then
        combine (`Assoc [ ("id", `String iri) ]) json
      else
        json
  | _ -> json
