open Yojson.Basic

let is_container json =
  match json |> Util.member "type" with
  | `List [ `String "BasicContainer"; `String "AnnotationCollection" ] -> true
  | `List [ `String "AnnotationCollection"; `String "BasicContainer" ] -> true
  | `String "AnnotationCollection" -> true
  | _ -> false

let create_worker json id host =
  let open Util in
  if
    json |> member "id" = `Null
    && json |> member "created" = `Null
  then
    let iri = host ^ "/annotations/" ^ id ^ "/" in
    let timestamp = Utils.Time.get_timestamp () in
    let id = `String iri in
    let type_ = json |> member "type" in
    let created = `String timestamp in
    let context = json |> member "@context" in
    let label = json |> member "label" in
    Result.ok
      (`Assoc
         [
           ("@context", context);
           ("id", id);
           ("type", type_);
           ("label", label);
           ("created", created);
         ]
      |> Utils.Json.filter_null)
  else Result.error "an id or created/modified timestamp can not be supplied"

let create ~data ~id ~host =
  match from_string data with
  | exception Yojson.Json_error m -> Result.error m
  | json ->
      if is_container json then create_worker json id host
      else Result.error "container type not found"

let update_worker json id host =
  let open Util in
  let iri = host ^ "/annotations/" ^ id in
  let id = `String iri in
  let id' = json |> member "id" in
  if id = id' then
    if json |> member "modified" = `Null then
      let timestamp = Utils.Time.get_timestamp () in
      let modified = `String timestamp in
      let annotation = combine (`Assoc [ ("modified", modified) ]) json in
      Result.ok annotation
    else Result.error "a modified timestamp can not be supplied"
  else Result.error "the id supplied was not valid"

let update ~data ~id ~host =
  match from_string data with
  | exception Yojson.Json_error m -> Result.error m
  | json ->
      if is_container json then
        update_worker json id host
      else Result.error "container type not found"

let annotation_page_id json target =
  let open Utils in
  let id = json |> Util.member "id" in
  let params = Json.id_helper 0 target in
  id |> function `String x -> `String (x ^ params) | _ -> `Null

let last json target total limit =
  let open Utils in
  let last_page = Math.calculate_page total limit in
  if last_page > 0 then
    let id = json |> Util.member "id" in
    let params = Json.id_helper last_page target in
    id |> function `String x -> `String (x ^ params) | _ -> `Null
  else `Null

let next json page target total limit =
  let open Utils in
  let id = json |> Util.member "id" in
  let last_page = Math.calculate_page total limit in
  if page < last_page then
    let next = Json.id_helper (page + 1) target in
    id |> function `String x -> `String (x ^ next) | _ -> `Null
  else `Null

let first json page target total limit =
  let open Util in
  let id = annotation_page_id json target in
  let items = json |> member "items" in
  let next = next json page target total limit in
  `Assoc
    [
      ("id", id);
      ("type", `String "AnnotationPage");
      ("items", items);
      ("next", next);
    ]
  |> Utils.Json.filter_null

let collection_worker json page target total limit =
  let open Util in
  let id = json |> Util.member "id" in
  let type_ = json |> member "type" in
  let first = first json page target total limit in
  let last = last json target total limit in
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

let collection json ~total ~limit ~target =
  collection_worker json 0 target total limit |> to_string
