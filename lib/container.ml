open Lwt.Infix

type t = { page_limit : int; mutable representation : string }

let create ~page_limit ~representation = { page_limit; representation }
let get_representation ~ctx = ctx.representation

let set_representation ~ctx ~representation =
  ctx.representation <- representation

let get_annotation ~db ~key = Db.get ~ctx:db ~key

let get_value term json =
  let open Ezjsonm in
  find_opt json [ term ]

let gen_id_page id page =
  let open Ezjsonm in
  let suffix = Printf.sprintf "?page=%d" page in
  Some (string (id ^ suffix))

let gen_id_collection id =
  let open Ezjsonm in
  Some (string (id ^ "/"))

let gen_type_page () = Some (Ezjsonm.string "AnnotationPage")

let gen_type_collection () =
  Some (Ezjsonm.strings [ "BasicContainer"; "AnnotationCollection" ])

let gen_total count = Some (Ezjsonm.int count)

let gen_part_of id_value count main =
  let open Ezjsonm in
  let id = gen_id_collection id_value in
  let created = get_value "created" main in
  let modified = get_value "modified" main in
  let label = get_value "label" main in
  let total = gen_total count in
  let json = dict [] in
  let json = update json [ "id" ] id in
  let json = update json [ "created" ] created in
  let json = update json [ "modified" ] modified in
  let json = update json [ "total" ] total in
  let json = update json [ "label" ] label in
  Some json

let gen_prefer_contained_iris collection =
  let open Ezjsonm in
  Some (list (fun x -> x) (get_list (fun x -> find x [ "id" ]) collection))

let gen_prefer_contained_descriptions collection = Some collection

let gen_items collection representation =
  match representation with
  | "PreferContainedDescriptions" ->
      gen_prefer_contained_descriptions collection
  | "PreferContainedIRIs" -> gen_prefer_contained_iris collection
  | "PreferMinimalContainer" -> None
  | _ -> gen_prefer_contained_descriptions collection

let gen_start_index page limit =
  let index = page * limit in
  Some (Ezjsonm.int index)

let gen_next id page count limit =
  let last_page = count / limit in
  if page < last_page then gen_id_page id (page + 1) else None

let gen_prev id page = if page > 0 then gen_id_page id (page - 1) else None

let gen_last id count limit =
  let last_page = count / limit in
  if last_page > 0 then gen_id_page id last_page else None

let get_string_value term json =
  let open Ezjsonm in
  get_string (Option.get (get_value term json))

let annotation_page_response page count limit main collection representation =
  let open Ezjsonm in
  let context = get_value "@context" main in
  let id_value = get_string_value "id" main in
  let id = gen_id_page id_value page in
  let type_page = gen_type_page () in
  let part_of = gen_part_of id_value count main in
  let start_index = gen_start_index page limit in
  let prev = gen_prev id_value page in
  let next = gen_next id_value page count limit in
  let items = gen_items collection representation in
  let json = dict [] in
  let json = update json [ "@context" ] context in
  let json = update json [ "id" ] id in
  let json = update json [ "type" ] type_page in
  let json = update json [ "partOf" ] part_of in
  let json = update json [ "startIndex" ] start_index in
  let json = update json [ "prev" ] prev in
  let json = update json [ "next" ] next in
  let json = update json [ "items" ] items in
  json

let get_annotation_page ~ctx ~db ~key ~page =
  Db.get ~ctx:db ~key >>= fun main ->
  let limit = ctx.page_limit in
  let representation = ctx.representation in
  let k = List.cons (List.hd key) [ "collection" ] in
  Db.count ~ctx:db ~key:k >>= fun count ->
  match count with
  | _ when page < 0 -> Lwt.return None
  | _ when page > count / limit -> Lwt.return None
  | 0 when page > 0 -> Lwt.return None
  | 0 ->
      Lwt.return
        (Some
           (annotation_page_response page count limit main (`A [])
              representation))
  | _ ->
      Db.get_collection ~ctx:db ~key:k ~offset:(page * limit) ~length:limit
      >|= fun collection ->
      Some
        (annotation_page_response page count limit main collection
           representation)

let gen_first id_value count limit collection representation =
  let open Ezjsonm in
  let id = gen_id_page id_value 0 in
  let type_page = gen_type_page () in
  let next = gen_next id_value 0 count limit in
  let items = gen_items collection representation in
  let json = dict [] in
  let json = update json [ "id" ] id in
  let json = update json [ "type" ] type_page in
  let json = update json [ "items" ] items in
  let json = update json [ "next" ] next in
  Some json

let annotation_collection_response count limit main collection representation =
  let open Ezjsonm in
  let context = get_value "@context" main in
  let id_value = get_string_value "id" main in
  let id = gen_id_collection id_value in
  let type_collection = gen_type_collection () in
  let label = get_value "label" main in
  let first = gen_first id_value count limit collection representation in
  let created = get_value "created" main in
  let modified = get_value "modified" main in
  let total = gen_total count in
  let last = gen_last id_value count limit in
  let json = dict [] in
  let json = update json [ "@context" ] context in
  let json = update json [ "id" ] id in
  let json = update json [ "type" ] type_collection in
  let json = update json [ "label" ] label in
  let json = update json [ "created" ] created in
  let json = update json [ "modified" ] modified in
  let json = update json [ "total" ] total in
  let json = update json [ "first" ] first in
  let json = update json [ "last" ] last in
  json

let get_annotation_collection ~ctx ~db ~key =
  Db.get ~ctx:db ~key >>= fun main ->
  let limit = ctx.page_limit in
  let representation = ctx.representation in
  let k = List.cons (List.hd key) [ "collection" ] in
  Db.count ~ctx:db ~key:k >>= fun count ->
  match count with
  | 0 ->
      Lwt.return
        (annotation_collection_response count limit main (`A []) representation)
  | _ ->
      Db.get_collection ~ctx:db ~key:k ~offset:0 ~length:limit
      >|= fun collection ->
      annotation_collection_response count limit main collection representation

let modify_container_timestamp db container_id =
  let modified_key = [ container_id; "main"; "modified" ] in
  Db.add ~ctx:db ~key:modified_key
    ~json:(Ezjsonm.string (Utils.get_timestamp ()))
    ~message:("POST " ^ Utils.key_to_string modified_key)

let add_or_update_annotation ~db ~key ~container_id ~json ~message =
  modify_container_timestamp db container_id >>= fun () ->
  Db.add ~ctx:db ~key ~json ~message

let add_annotation = add_or_update_annotation
let update_annotation = add_or_update_annotation
let add_container ~db ~key ~json ~message = Db.add ~ctx:db ~key ~json ~message

let delete_annotation ~db ~key ~container_id ~message =
  modify_container_timestamp db container_id >>= fun () ->
  Db.delete ~ctx:db ~key ~message

let delete_container ~db ~key ~message = Db.delete ~ctx:db ~key ~message
let get_hash ~db ~key = Db.get_hash ~ctx:db ~key
let container_or_annotation_exists ~db ~key = Db.exists ~ctx:db ~key
let container_exists = container_or_annotation_exists
let annotation_exists = container_or_annotation_exists

let get_page request =
  match Dream.query request "page" with
  | None -> 0
  | Some page -> (
      match int_of_string_opt page with None -> 0 | Some value -> value)
