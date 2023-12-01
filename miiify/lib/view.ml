open Lwt
open Config_t

let get_status config _ = Response.status config.miiify_status
let head_status config request = get_status config request >>= Response.head
let options_status _ = Response.options_status

let get_version config _ = Response.version config.miiify_version
let head_version config request = get_version config request >>= Response.head
let options_version _ = Response.options_version

let options_container _ = Response.options_container

let get_container db request =
  let open Response in
  let id = Dream.param request "container_id" in
  Controller.get_container_hash ~db ~id >>= function
  | Some hash -> (
      Header.get_if_none_match request |> function
      | Some etag when hash = etag -> not_modified "container not modified"
      | _ ->
          Controller.get_container ~db ~container_id:id >>= get_container ~hash)
  | None -> not_found "container not found"

let head_container db request = get_container db request >>= Response.head

let post_container db request =
  let open Response in
  let id = Header.get_id request in
  let host = Header.get_host request in
  let message = Utils.Info.message request in
  Controller.container_exists ~db ~id >>= function
  | true -> bad_request "container exists"
  | false -> (
      Dream.body request >>= Controller.post_container ~db ~id ~host ~message
      >>= function
      | Ok result -> result >>= create_container
      | Error m -> bad_request m)

let put_container_worker request db id host message =
  let open Response in
  Dream.body request >>= Controller.put_container ~db ~id ~host ~message
  >>= function
  | Ok result -> result >>= update_container
  | Error m -> bad_request m

let put_container config db request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let host = Header.get_host request in
  let message = Utils.Info.message request in
  Controller.get_container_hash ~db ~id:container_id >>= function
  | Some hash -> (
      Header.get_if_match request |> function
      | Some etag when hash = etag ->
          put_container_worker request db container_id host message
      | None when config.avoid_mid_air_collisions = true ->
          precondition_failed "etag required"
      | None when config.avoid_mid_air_collisions = false ->
          put_container_worker request db container_id host message
      | _ -> precondition_failed "failed to match etag")
  | None -> not_found "container not found"

let delete_container config db request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let message = Utils.Info.message request in
  Controller.get_container_hash ~db ~id:container_id >>= function
  | Some hash -> (
      Header.get_if_match request |> function
      | Some etag when hash = etag ->
          Controller.delete_container ~db ~id:container_id ~message
          >>= delete_container
      | None when config.avoid_mid_air_collisions = true ->
          precondition_failed "etag required"
      | None when config.avoid_mid_air_collisions = false ->
          Controller.delete_container ~db ~id:container_id ~message
          >>= delete_container
      | _ -> precondition_failed "failed to match etag")
  | None -> not_found "container not found"

let post_annotation db request =
  let open Response in
  let annotation_id = Header.get_id request in
  let container_id = Dream.param request "container_id" in
  let host = Header.get_host request in
  let message = Utils.Info.message request in
  Controller.container_exists ~db ~id:container_id >>= function
  | true -> (
      Controller.annotation_exists ~db ~container_id ~annotation_id >>= function
      | true -> bad_request "annotation exists"
      | false -> (
          Dream.body request
          >>= Controller.post_annotation ~db ~container_id ~annotation_id ~host
                ~message
          >>= function
          | Ok result -> result >>= create_annotation
          | Error m -> bad_request m))
  | false -> not_found "container does not exist"

let put_annotation_worker request db container_id annotation_id host message =
  let open Response in
  Dream.body request
  >>= Controller.put_annotation ~db ~container_id ~annotation_id ~host ~message
  >>= function
  | Ok result -> result >>= update_annotation
  | Error m -> bad_request m

let put_annotation config db request =
  let open Response in
  let annotation_id = Dream.param request "annotation_id" in
  let container_id = Dream.param request "container_id" in
  let host = Header.get_host request in
  let message = Utils.Info.message request in
  Controller.get_annotation_hash ~db ~container_id ~annotation_id >>= function
  | Some hash -> (
      Header.get_if_match request |> function
      | Some etag when hash = etag ->
          put_annotation_worker request db container_id annotation_id host
            message
      | None when config.avoid_mid_air_collisions = true ->
          precondition_failed "etag required"
      | None when config.avoid_mid_air_collisions = false ->
          put_annotation_worker request db container_id annotation_id host
            message
      | _ -> precondition_failed "failed to match etag")
  | None -> not_found "annotation not found"

let get_annotation_collection config db request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let target = Header.get_target request in
  Controller.get_collection_hash ~db ~id:container_id >>= function
  | Some hash -> (
      Header.get_if_none_match request |> function
      | Some etag when hash = etag -> not_modified "container not modified"
      | _ ->
          Controller.get_annotation_collection ~config ~db ~id:container_id
            ~target
          >>= get_collection ~hash)
  | None -> not_found "no collection found"

let get_annotation_page config db request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let page = Header.get_page request in
  let target = Header.get_target request in
  Controller.get_collection_hash ~db ~id:container_id >>= function
  | Some hash -> (
      Header.get_if_none_match request |> function
      | Some etag when hash = etag -> not_modified "container not modified"
      | _ -> (
          Controller.get_annotation_page ~config ~db ~id:container_id ~page
            ~target
          >>= function
          | Some page -> get_page page ~hash
          | None -> not_found "page not found"))
  | None -> not_found "no pages found"

let get_annotations config db request =
  let open Response in
  let open Header in
  let container =
    param_exists request "page" |> function
    | true -> get_annotation_page config db request
    | false -> get_annotation_collection config db request
  in
  get_prefer request ~default:config.container_representation |> function
  | "PreferContainedDescriptions" -> container |> prefer_contained_descriptions
  | "PreferContainedIRIs" -> container |> prefer_contained_iris
  | "PreferMinimalContainer" -> container |> prefer_minimal_container
  | v -> bad_request (Printf.sprintf "%s not recognised" v)

let head_annotations config db request =
  get_annotations config db request >>= Response.head

let get_annotation db request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let annotation_id = Dream.param request "annotation_id" in
  Controller.get_annotation_hash ~db ~container_id ~annotation_id >>= function
  | Some hash -> (
      Header.get_if_none_match request |> function
      | Some etag when hash = etag -> not_modified "container not modified"
      | _ ->
          Controller.get_annotation ~db ~container_id ~annotation_id
          >>= get_annotation ~hash)
  | None -> not_found "annotation not found"

let head_annotation db request = get_annotation db request >>= Response.head

let delete_annotation config db request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let annotation_id = Dream.param request "annotation_id" in
  let message = Utils.Info.message request in
  Controller.get_annotation_hash ~db ~container_id ~annotation_id >>= function
  | Some hash -> (
      Header.get_if_match request |> function
      | Some etag when hash = etag ->
          Controller.delete_annotation ~db ~container_id ~annotation_id ~message
          >>= delete_annotation
      | None when config.avoid_mid_air_collisions = true ->
          precondition_failed "etag required"
      | None when config.avoid_mid_air_collisions = false ->
          Controller.delete_annotation ~db ~container_id ~annotation_id ~message
          >>= delete_annotation
      | _ -> precondition_failed "failed to match etag")
  | None -> not_found "annotation not found"

let get_manifest db request =
  let open Response in
  let id = Dream.param request "manifest_id" in
  Controller.get_manifest_hash ~db ~id >>= function
  | Some hash -> (
      Header.get_if_none_match request |> function
      | Some etag when hash = etag -> not_modified "manifest not modified"
      | _ -> Controller.get_manifest ~db ~id >>= get_manifest ~hash)
  | None -> not_found "manifest not found"

let head_manifest db request = get_manifest db request >>= Response.head

let post_manifest db request =
  let open Response in
  let id = Dream.param request "manifest_id" in
  let message = Utils.Info.message request in
  Controller.manifest_exists ~db ~id >>= function
  | true -> bad_request "manifest exists"
  | false -> (
      Dream.body request >>= Controller.post_manifest ~db ~id ~message
      >>= function
      | Ok result -> result >>= create_manifest
      | Error m -> bad_request m)

let put_manifest_worker request db id message =
  let open Response in
  Dream.body request >>= Controller.put_manifest ~db ~id ~message >>= function
  | Ok result -> result >>= update_manifest
  | Error m -> bad_request m

let put_manifest config db request =
  let open Response in
  let id = Dream.param request "manifest_id" in
  let message = Utils.Info.message request in
  Controller.get_manifest_hash ~db ~id >>= function
  | Some hash -> (
      Header.get_if_match request |> function
      | Some etag when hash = etag -> put_manifest_worker request db id message
      | None when config.avoid_mid_air_collisions = true ->
          precondition_failed "etag required"
      | None when config.avoid_mid_air_collisions = false ->
          put_manifest_worker request db id message
      | _ -> precondition_failed "failed to match etag")
  | None -> not_found "manifest not found"

let delete_manifest config db request =
  let open Response in
  let id = Dream.param request "manifest_id" in
  let message = Utils.Info.message request in
  Controller.get_manifest_hash ~db ~id >>= function
  | Some hash -> (
      Header.get_if_match request |> function
      | Some etag when hash = etag ->
          Controller.delete_manifest ~db ~id ~message >>= delete_container
      | None when config.avoid_mid_air_collisions = true ->
          precondition_failed "etag required"
      | None when config.avoid_mid_air_collisions = false ->
          Controller.delete_manifest ~db ~id ~message >>= delete_container
      | _ -> precondition_failed "failed to match etag")
  | None -> not_found "manifest not found"
