open Yojson.Basic

let is_annotation json =
  match json |> Util.member "type" with
  | `String "Annotation" -> true
  | _ -> false

let create_worker json container_id annotation_id host =
  let open Util in
  if json |> member "id" = `Null && json |> member "created" = `Null then
    let iri = host ^ "/annotations/" ^ container_id ^ "/" ^ annotation_id in
    let timestamp = Utils.Time.get_timestamp () in
    let id = `String iri in
    let created = `String timestamp in
    let annotation =
      combine (`Assoc [ ("id", id); ("created", created) ]) json
    in
    Result.ok annotation
  else Result.error "an id or created timestamp can not be supplied"

let create ~data ~container_id ~annotation_id ~host =
  match from_string data with
  | exception Yojson.Json_error m -> Result.error m
  | json ->
      if is_annotation json then
        create_worker json container_id annotation_id host
      else Result.error "annotation type not found"

let update_worker json container_id annotation_id host =
  let open Util in
  let iri = host ^ "/annotations/" ^ container_id ^ "/" ^ annotation_id in
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

let update ~data ~container_id ~annotation_id ~host =
  match from_string data with
  | exception Yojson.Json_error m -> Result.error m
  | json ->
      if is_annotation json then
        update_worker json container_id annotation_id host
      else Result.error "annotation type not found"

let next json page target total limit =
  let open Utils in
  let id = json |> Util.member "id" in
  let last_page = Math.calculate_page total limit in
  if page < last_page then
    let next = Json.id_helper (page + 1) target in
    id |> function `String x -> `String (x ^ next) | _ -> `Null
  else `Null

let prev json page target =
  let open Utils in
  let id = json |> Util.member "id" in
  if page > 0 then
    let next = Json.id_helper (page - 1) target in
    id |> function `String x -> `String (x ^ next) | _ -> `Null
  else `Null

let annotation_page_id json page target =
  let open Utils in
  let id = json |> Util.member "id" in
  let params = Json.id_helper page target in
  id |> function `String x -> `String (x ^ params) | _ -> `Null

let part_of json total =
  let open Util in
  let id = json |> member "id" in
  let type_ = json |> member "type" in
  let total = total |> function 0 -> `Null | _ -> `Int total in
  let label = json |> member "label" in
  let created = json |> member "created" in
  let modified = json |> member "modified" in
  `Assoc
    [
      ("id", id);
      ("type", type_);
      ("total", total);
      ("label", label);
      ("created", created);
      ("modified", modified);
    ]
  |> Utils.Json.filter_null

let page_worker json page total limit target =
  let open Util in
  let id = annotation_page_id json page target in
  let context = json |> member "@context" in
  let part_of = part_of json total in
  let start_index = `Int (page * limit) in
  let items = json |> member "items" in
  let next = next json page target total limit in
  let prev = prev json page target in
  `Assoc
    [
      ("@context", context);
      ("id", id);
      ("type", `String "AnnotationPage");
      ("partOf", part_of);
      ("startIndex", start_index);
      ("items", items);
      ("next", next);
      ("prev", prev);
    ]
  |> Utils.Json.filter_null

let page json ~page ~total ~limit ~target =
  Some (page_worker json page total limit target |> to_string)

let annotation json = json |> to_string
