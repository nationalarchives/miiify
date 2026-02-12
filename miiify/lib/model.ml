open Lwt
open Lwt.Syntax
open Yojson.Basic

let create ~repository_name = 
  Db.set_backend "pack";  (* Always use Pack for runtime *)
  Db.create ~fname:repository_name

let get_container ~db ~container_id =
  let* data = Db.get ~db ~key:[ container_id; "metadata" ] in
  from_string data |> Lwt.return

let filter_items_helper item keys target =
  item |> Util.path keys |> function
  | Some x -> x = `String target
  | None -> false

let filter_items target items =
  match target with
  | Some target ->
      List.filter
        (fun item ->
          filter_items_helper item [ "target" ] target
          || filter_items_helper item [ "target"; "source" ] target)
        items
  | None -> items

let get_annotations ~db ~container_id ~offset ~length ~target =
  let* main = Db.get ~db ~key:[ container_id; "metadata" ] in
  let container = from_string main in
  let* collection =
    Db.get_tree ~db ~key:[ container_id; "collection" ] ~offset ~length
  in
  let items = List.map (fun x -> from_string x) collection in
  let filtered_items = filter_items target items in
  let annotations = `Assoc [ ("items", `List filtered_items) ] in
  Util.combine container annotations |> Lwt.return

let get_annotations_with_ids ~db ~container_id ~offset ~length ~target =
  let* main = Db.get ~db ~key:[ container_id; "metadata" ] in
  let container = from_string main in
  let* collection =
    Db.get_tree_with_keys ~db ~key:[ container_id; "collection" ] ~offset ~length
  in
  let items =
    List.map (fun (slug, json_str) -> (slug, from_string json_str)) collection
  in
  let filtered_items_with_slugs =
    match target with
    | Some target_value ->
        List.filter
          (fun (_slug, item_json) ->
            filter_items_helper item_json [ "target" ] target_value
            || filter_items_helper item_json [ "target"; "source" ] target_value)
          items
    | None -> items
  in
  let annotations =
    `Assoc [ ("items", `List (List.map snd filtered_items_with_slugs)) ]
  in
  Lwt.return (container, filtered_items_with_slugs, annotations)

let total_filtered ~db ~container_id ~target =
  match target with
  | None -> Db.total ~db ~key:[ container_id; "collection" ]
  | Some target_value ->
      let* total_items = Db.total ~db ~key:[ container_id; "collection" ] in
      if total_items <= 0 then Lwt.return 0
      else
        let* collection =
          Db.get_tree_with_keys ~db ~key:[ container_id; "collection" ] ~offset:0
            ~length:total_items
        in
        let count =
          List.fold_left
            (fun acc (_slug, json_str) ->
              let item_json = from_string json_str in
              if
                filter_items_helper item_json [ "target" ] target_value
                || filter_items_helper item_json [ "target"; "source" ]
                     target_value
              then acc + 1
              else acc)
            0 collection
        in
        Lwt.return count

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
  Db.delete ~db ~key:[ container_id; "metadata" ] ~message >>= fun () ->
  Db.delete ~db ~key:[ container_id; "collection" ] ~message

let container_exists ~db ~container_id =
  Db.exists ~db ~key:[ container_id; "metadata" ]

let annotation_exists ~db ~container_id ~annotation_id =
  Db.exists ~db ~key:[ container_id; "collection"; annotation_id ]

let get_collection_hash ~db ~container_id =
  Db.get_hash ~db ~key:[ container_id; "collection" ]

let get_container_hash ~db ~container_id =
  Db.get_hash ~db ~key:[ container_id; "metadata" ]

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
