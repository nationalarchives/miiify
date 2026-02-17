open Lwt.Syntax
open Yojson.Basic

let create ~repository_name = 
  Db.set_backend "pack";  (* Always use Pack for runtime *)
  Db.create ~fname:repository_name

let get_container ~db ~container_id =
  let* data = Db.get ~db ~key:[ container_id; "metadata" ] in
  from_string data |> Lwt.return

let get_annotations ~db ~container_id ~offset ~length =
  let* main = Db.get ~db ~key:[ container_id; "metadata" ] in
  let container = from_string main in
  let* collection =
    Lwt.catch
      (fun () -> Db.get_tree_with_keys ~db ~key:[ container_id; "collection" ] ~offset ~length)
      (fun _exn -> Lwt.return [])
  in
  let items_with_slugs =
    List.map (fun (slug, json_str) -> (slug, from_string json_str)) collection
  in
  let annotations =
    `Assoc [ ("items", `List (List.map snd items_with_slugs)) ]
  in
  Lwt.return (container, items_with_slugs, annotations)

let get_annotation ~db ~container_id ~annotation_id =
  let* data = Db.get ~db ~key:[ container_id; "collection"; annotation_id ] in
  from_string data |> Lwt.return

let get_annotation_hash ~db ~container_id ~annotation_id =
  Db.get_hash ~db ~key:[ container_id; "collection"; annotation_id ]

let container_exists ~db ~container_id =
  Db.exists ~db ~key:[ container_id; "metadata" ]

let annotation_exists ~db ~container_id ~annotation_id =
  Db.exists ~db ~key:[ container_id; "collection"; annotation_id ]

let get_collection_hash ~db ~container_id =
  Db.get_hash ~db ~key:[ container_id; "collection" ]

let get_container_hash ~db ~container_id =
  Db.get_hash ~db ~key:[ container_id; "metadata" ]

let total ~db ~container_id = Db.total ~db ~key:[ container_id; "collection" ]
