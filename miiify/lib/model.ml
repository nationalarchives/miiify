open Lwt
open Lwt.Syntax
open Yojson.Basic
open Config_t

let create ~config = Db.create ~fname:config.repository_name

let filter_items target items =
  match target with
  | Some target ->
      List.filter (fun x -> x |> Util.member "target" = `String target) items
  | None -> items

let get_annotations ~db ~container_id ~offset ~length ~target =
  let* main = Db.get ~db ~key:[ container_id; "main" ] in
  let container = from_string main in
  let* collection =
    Db.get_tree ~db ~key:[ container_id; "collection" ] ~offset ~length
  in
  let items = List.map (fun x -> from_string x) collection in
  let filtered_items = filter_items target items in
  let annotations = `Assoc [ ("items", `List filtered_items) ] in
  Util.combine container annotations |> Lwt.return

let get_annotation ~db ~container_id ~annotation_id =
  let* data = Db.get ~db ~key:[ container_id; "collection"; annotation_id ] in
  from_string data |> Lwt.return

let get_annotation_hash ~db ~container_id ~annotation_id =
  Db.get_hash ~db ~key:[ container_id; "collection"; annotation_id ]

let add_annotation ~db ~container_id ~annotation_id ~json ~message =
  let data = to_string json in
  let* () =
    Db.set ~db ~key:[ container_id; "collection"; annotation_id ] ~data ~message
  in
  data |> Lwt.return

let update_annotation ~db ~container_id ~annotation_id ~json ~message =
  add_annotation ~db ~container_id ~annotation_id ~json ~message

let delete_annotation ~db ~container_id ~annotation_id =
  Db.delete ~db ~key:[ container_id; "collection"; annotation_id ]

let add_container ~db ~container_id ~json ~message =
  let data = to_string json in
  let* () = Db.set ~db ~key:[ container_id; "main" ] ~data ~message in
  data |> Lwt.return

let update_container ~db ~container_id ~json ~message =
  add_container ~db ~container_id ~json ~message

let delete_container ~db ~container_id ~message =
  Db.delete ~db ~key:[ container_id; "main" ] ~message >>= fun () ->
  Db.delete ~db ~key:[ container_id; "collection" ] ~message

let container_exists ~db ~container_id =
  Db.exists ~db ~key:[ container_id; "main" ]

let annotation_exists ~db ~container_id ~annotation_id =
  Db.exists ~db ~key:[ container_id; "collection"; annotation_id ]

let get_collection_hash ~db ~container_id =
  Db.get_hash ~db ~key:[ container_id; "collection" ]

let get_container_hash ~db ~container_id =
  Db.get_hash ~db ~key:[ container_id; "main" ]

let total ~db ~container_id = Db.total ~db ~key:[ container_id; "collection" ]

let get_manifest ~db ~manifest_id =
  let* data = Db.get ~db ~key:[ ".manifest"; manifest_id ] in
  from_string data |> Lwt.return

let add_manifest ~db ~manifest_id ~json ~message =
  let data = to_string json in
  let* () = Db.set ~db ~key:[ ".manifest"; manifest_id ] ~data ~message in
  data |> Lwt.return

let update_manifest ~db ~manifest_id ~json ~message =
  add_manifest ~db ~manifest_id ~json ~message

let delete_manifest ~db ~manifest_id ~message =
  Db.delete ~db ~key:[ ".manifest"; manifest_id ] ~message

let manifest_exists ~db ~manifest_id =
  Db.exists ~db ~key:[ ".manifest"; manifest_id ]

let get_manifest_hash ~db ~manifest_id =
  Db.get_hash ~db ~key:[ ".manifest"; manifest_id ]
