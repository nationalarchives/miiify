open Lwt.Syntax
open Lwt.Infix
open Config_t

let get_container ~db ~container_id =
  Model.get_container ~db ~container_id >|= Container.container

let post_container ~db ~id ~host ~message data =
  Container.create ~id ~host ~data |> function
  | Ok json ->
      let result = Model.add_container ~db ~container_id:id ~json ~message in
      Lwt.return_ok result
  | Error m -> Lwt.return_error m

let put_container ~db ~id ~host ~message data =
  Container.update ~id ~host ~data |> function
  | Ok json ->
      let result = Model.update_container ~db ~container_id:id ~json ~message in
      Lwt.return_ok result
  | Error m -> Lwt.return_error m

let delete_container ~db ~id ~message =
  Model.delete_container ~db ~container_id:id ~message

let post_annotation ~db ~container_id ~annotation_id ~host ~message data
    =
  Annotation.create ~container_id ~annotation_id ~host ~data |> function
  | Ok json ->
      let result =
        Model.add_annotation ~db ~container_id ~annotation_id ~json ~message
      in
      Lwt.return_ok result
  | Error m -> Lwt.return_error m

let put_annotation ~db ~container_id ~annotation_id ~host ~message data
    =
  Annotation.update ~container_id ~annotation_id ~host ~data |> function
  | Ok json ->
      let result =
        Model.update_annotation ~db ~container_id ~annotation_id ~json ~message
      in
      Lwt.return_ok result
  | Error m -> Lwt.return_error m

let container_exists ~db ~id =
  Model.container_exists ~db ~container_id:id

let annotation_exists ~db ~container_id ~annotation_id =
  Model.annotation_exists ~db ~container_id ~annotation_id

let get_annotation_collection ~config ~db ~id ~target =
  let* total = Model.total ~db ~container_id:id in
  Model.get_annotations ~db ~container_id:id ~offset:0
    ~length:config.container_page_limit ~target
  >|= Container.collection ~total ~target ~limit:config.container_page_limit

let get_annotation_page ~config ~db ~id ~page ~target =
  let open Utils.Math in
  let limit = config.container_page_limit in
  let* total = Model.total ~db ~container_id:id in
  if page < 0 || page > calculate_page total limit then Lwt.return_none
  else
    Model.get_annotations ~db ~container_id:id ~offset:(page * limit)
      ~length:limit ~target
    >|= Annotation.page ~total ~page ~target ~limit

let get_collection_hash ~db ~id =
  Model.get_collection_hash ~db ~container_id:id

let get_container_hash ~db ~id =
  Model.get_container_hash ~db ~container_id:id

let get_annotation_hash ~db ~container_id ~annotation_id =
  Model.get_annotation_hash ~db ~container_id ~annotation_id

let get_annotation ~db ~container_id ~annotation_id =
  Model.get_annotation ~db ~container_id ~annotation_id
  >|= Annotation.annotation

let delete_annotation ~db ~container_id ~annotation_id ~message =
  Model.delete_annotation ~db ~container_id ~annotation_id ~message

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

let get_manifest_hash ~db ~id =
  Model.get_manifest_hash ~db ~manifest_id:id
