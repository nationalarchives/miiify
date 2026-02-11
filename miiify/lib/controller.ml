open Lwt.Syntax
open Lwt.Infix

let get_container ~db ~container_id ~base_url =
  Model.get_container ~db ~container_id >|= fun json ->
  let json_with_id = Container.inject_id json ~container_id ~base_url in
  Container.container json_with_id

let post_container ~db ~id ~base_url ~message data =
  Container.create ~id ~base_url ~data |> function
  | Ok json ->
      let result = Model.add_container ~db ~container_id:id ~json ~message in
      Lwt.return_ok result
  | Error m -> Lwt.return_error m

let put_container ~db ~id ~base_url ~message data =
  Container.update ~id ~base_url ~data |> function
  | Ok json ->
      let result = Model.update_container ~db ~container_id:id ~json ~message in
      Lwt.return_ok result
  | Error m -> Lwt.return_error m

let delete_container ~db ~id ~message =
  Model.delete_container ~db ~container_id:id ~message

let post_annotation ~db ~container_id ~annotation_id ~base_url ~message ~validate data =
  Specification.validate ~data ~enabled:validate |> function
  | Ok () -> (
      Annotation.create ~container_id ~annotation_id ~base_url ~data |> function
      | Ok json ->
          let result =
            Model.add_annotation ~db ~container_id ~annotation_id ~json ~message
          in
          Lwt.return_ok result
      | Error m -> Lwt.return_error m)
  | Error m -> Lwt.return_error m

let put_annotation ~db ~container_id ~annotation_id ~base_url ~message ~validate data =
  Specification.validate ~data ~enabled:validate |> function
  | Ok () -> (
    Annotation.update ~container_id ~annotation_id ~base_url ~data |> function
    | Ok json ->
        let result =
          Model.update_annotation ~db ~container_id ~annotation_id ~json ~message
        in
        Lwt.return_ok result
    | Error m -> Lwt.return_error m)
  | Error m -> Lwt.return_error m


let container_exists ~db ~id = Model.container_exists ~db ~container_id:id

let annotation_exists ~db ~container_id ~annotation_id =
  Model.annotation_exists ~db ~container_id ~annotation_id

let get_annotation_collection ~page_limit ~db ~id ~target ~base_url =
  let* total = Model.total ~db ~container_id:id in
  let* (container_json, items_with_slugs, _) =
    Model.get_annotations_with_ids ~db ~container_id:id ~offset:0 ~length:page_limit ~target
  in
  (* Inject ID into container *)
  let container_with_id = Container.inject_id container_json ~container_id:id ~base_url in
  (* Inject IDs into annotations *)
  let items_with_ids = List.map (fun (slug, item_json) ->
    Annotation.inject_id item_json ~container_id:id ~annotation_id:slug ~base_url
  ) items_with_slugs in
  (* Combine into collection response *)
  let collection_json = `Assoc [("items", `List items_with_ids)] in
  let combined = Yojson.Basic.Util.combine container_with_id collection_json in
  combined |> Container.collection ~total ~target ~limit:page_limit |> Lwt.return

let get_annotation_page ~page_limit ~db ~id ~page ~target ~base_url =
  let open Utils.Math in
  let limit = page_limit in
  let* total = Model.total ~db ~container_id:id in
  if page < 0 || page > calculate_page total limit then Lwt.return_none
  else
    let* (container_json, items_with_slugs, _) =
      Model.get_annotations_with_ids ~db ~container_id:id ~offset:(page * limit)
        ~length:limit ~target
    in
    (* Inject ID into container *)
    let container_with_id = Container.inject_id container_json ~container_id:id ~base_url in
    (* Inject IDs into annotations *)
    let items_with_ids = List.map (fun (slug, item_json) ->
      Annotation.inject_id item_json ~container_id:id ~annotation_id:slug ~base_url
    ) items_with_slugs in
    (* Combine into page JSON *)
    let page_json = `Assoc [("items", `List items_with_ids)] in
    let combined = Yojson.Basic.Util.combine container_with_id page_json in
    combined |> Annotation.page ~total ~page ~target ~limit |> Lwt.return

let get_collection_hash ~db ~id = Model.get_collection_hash ~db ~container_id:id
let get_container_hash ~db ~id = Model.get_container_hash ~db ~container_id:id

let get_annotation_hash ~db ~container_id ~annotation_id =
  Model.get_annotation_hash ~db ~container_id ~annotation_id

let get_annotation ~db ~container_id ~annotation_id ~base_url =
  let* json = Model.get_annotation ~db ~container_id ~annotation_id in
  let json_with_id = Annotation.inject_id json ~container_id ~annotation_id ~base_url in
  json_with_id |> Annotation.annotation |> Lwt.return

let delete_annotation ~db ~container_id ~annotation_id ~message =
  Model.delete_annotation ~db ~container_id ~annotation_id ~message

(* Manifest functions removed - not used in simplified read-only API *)
(* 
let get_manifest ~db ~id =
  Model.get_manifest ~db ~manifest_id:id >|= Manifest.manifest

let post_manifest ~db ~id ~message data =
  Manifest.create ~data |> function
  | Ok json ->
      let result = Model.add_manifest ~db ~manifest_id:id ~json ~message in
      Lwt.return_ok result
  | Error m -> Lwt.return_error m

let put_manifest ~db ~id ~message data =
  Manifest.update ~data |> function
  | Ok json ->
      let result = Model.update_manifest ~db ~manifest_id:id ~json ~message in
      Lwt.return_ok result
  | Error m -> Lwt.return_error m

let delete_manifest ~db ~id ~message =
  Model.delete_manifest ~db ~manifest_id:id ~message

let manifest_exists ~db ~id = Model.manifest_exists ~db ~manifest_id:id
let get_manifest_hash ~db ~id = Model.get_manifest_hash ~db ~manifest_id:id
*)
