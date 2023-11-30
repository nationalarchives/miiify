open Lwt
open Config_t

let status config _ _ = Response.ok config.miiify_status
let version config _ _ = Response.ok config.miiify_version

let post_container config db request =
  let open Response in
  let id = Header.get_id request in
  let host = Header.get_host request in
  let message = Utils.Info.message request in
  Controller.container_exists ~config ~db ~id >>= function
  | true -> bad_request "container exists"
  | false -> (
      Dream.body request
      >>= Controller.post_container ~config ~db ~id ~host ~message
      >>= function
      | Ok result -> result >>= create_container
      | Error m -> bad_request m)

let put_container_worker request config db id host message =
  let open Response in
  Dream.body request >>= Controller.put_container ~config ~db ~id ~host ~message
  >>= function
  | Ok result -> result >>= update_container
  | Error m -> bad_request m

let put_container config db request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let host = Header.get_host request in
  let message = Utils.Info.message request in
  Controller.get_container_hash ~config ~db ~id:container_id >>= function
  | Some hash -> (
      Header.get_if_match request |> function
      | Some etag when hash = etag ->
          put_container_worker request config db container_id host message
      | None when config.avoid_mid_air_collisions = true ->
          precondition_failed "etag required"
      | None when config.avoid_mid_air_collisions = false ->
          put_container_worker request config db container_id host message
      | _ -> precondition_failed "failed to match etag")
  | None -> not_found "container not found"

let delete_container config db request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let message = Utils.Info.message request in
  Controller.get_container_hash ~config ~db ~id:container_id >>= function
  | Some hash -> (
      Header.get_if_match request |> function
      | Some etag when hash = etag ->
          Controller.delete_container ~config ~db ~id:container_id ~message
          >>= delete_container
      | None when config.avoid_mid_air_collisions = true ->
          precondition_failed "etag required"
      | None when config.avoid_mid_air_collisions = false ->
          Controller.delete_container ~config ~db ~id:container_id ~message
          >>= delete_container
      | _ -> precondition_failed "failed to match etag")
  | None -> not_found "container not found"

let post_annotation config db request =
  let open Response in
  let annotation_id = Header.get_id request in
  let container_id = Dream.param request "container_id" in
  let host = Header.get_host request in
  let message = Utils.Info.message request in
  Controller.container_exists ~config ~db ~id:container_id >>= function
  | true -> (
      Controller.annotation_exists ~config ~db ~container_id ~annotation_id
      >>= function
      | true -> bad_request "annotation exists"
      | false -> (
          Dream.body request
          >>= Controller.post_annotation ~config ~db ~container_id
                ~annotation_id ~host ~message
          >>= function
          | Ok result -> result >>= create_annotation
          | Error m -> bad_request m))
  | false -> not_found "container does not exist"

let put_annotation config db request =
  let open Response in
  let annotation_id = Dream.param request "annotation_id" in
  let container_id = Dream.param request "container_id" in
  let host = Header.get_host request in
  let message = Utils.Info.message request in
  Controller.get_annotation_hash ~config ~db ~container_id ~annotation_id
  >>= function
  | Some hash -> (
      Header.get_if_match request |> function
      | Some etag when hash = etag -> (
          Dream.body request
          >>= Controller.put_annotation ~config ~db ~container_id ~annotation_id
                ~host ~message
          >>= function
          | Ok result -> result >>= update_annotation
          | Error m -> bad_request m)
      | None -> (
          Dream.body request
          >>= Controller.put_annotation ~config ~db ~container_id ~annotation_id
                ~host ~message:(message ^ " no etag")
          >>= function
          | Ok result -> result >>= update_annotation
          | Error m -> bad_request m)
      | _ -> precondition_failed "failed to match etag")
  | None -> not_found "annotation not found"

let get_annotation_collection config db request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let target = Header.get_target request in
  Controller.get_collection_hash ~config ~db ~id:container_id >>= function
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
  Controller.get_collection_hash ~config ~db ~id:container_id >>= function
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

let get_container config db request =
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

let get_annotation config db request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let annotation_id = Dream.param request "annotation_id" in
  Controller.get_annotation_hash ~config ~db ~container_id ~annotation_id
  >>= function
  | Some hash -> (
      Header.get_if_none_match request |> function
      | Some etag when hash = etag -> not_modified "container not modified"
      | _ ->
          Controller.get_annotation ~config ~db ~container_id ~annotation_id
          >>= get_annotation ~hash)
  | None -> not_found "annotation not found"

let delete_annotation config db request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let annotation_id = Dream.param request "annotation_id" in
  let message = Utils.Info.message request in
  Controller.get_annotation_hash ~config ~db ~container_id ~annotation_id
  >>= function
  | Some hash -> (
      Header.get_if_match request |> function
      | Some etag when hash = etag ->
          Controller.delete_annotation ~config ~db ~container_id ~annotation_id
            ~message
          >>= delete_annotation
      | None ->
          Controller.delete_annotation ~config ~db ~container_id ~annotation_id
            ~message:(message ^ " no etag")
          >>= delete_annotation
      | _ -> precondition_failed "failed to match etag")
  | None -> not_found "annotation not found"

let get_manifest config db request =
  let open Response in
  let id = Dream.param request "manifest_id" in
  Controller.get_manifest_hash ~config ~db ~id >>= function
  | Some hash -> (
      Header.get_if_none_match request |> function
      | Some etag when hash = etag -> not_modified "manifest not modified"
      | _ -> Controller.get_manifest ~config ~db ~id >>= get_manifest ~hash)
  | None -> not_found "manifest not found"

let post_manifest config db request =
  let open Response in
  let id = Dream.param request "manifest_id" in
  let message = Utils.Info.message request in
  Controller.manifest_exists ~config ~db ~id >>= function
  | true -> bad_request "manifest exists"
  | false -> (
      Dream.body request >>= Controller.post_manifest ~config ~db ~id ~message
      >>= function
      | Ok result -> result >>= create_manifest
      | Error m -> bad_request m)

let put_manifest config db request =
  let open Response in
  let id = Dream.param request "manifest_id" in
  let message = Utils.Info.message request in
  Controller.get_manifest_hash ~config ~db ~id >>= function
  | Some hash -> (
      Header.get_if_match request |> function
      | Some etag when hash = etag -> (
          Dream.body request
          >>= Controller.put_manifest ~config ~db ~id ~message
          >>= function
          | Ok result -> result >>= update_manifest
          | Error m -> bad_request m)
      | None -> (
          Dream.body request
          >>= Controller.put_manifest ~config ~db ~id
                ~message:(message ^ " no etag")
          >>= function
          | Ok result -> result >>= update_manifest
          | Error m -> bad_request m)
      | _ -> precondition_failed "failed to match etag")
  | None -> not_found "manifest not found"

let delete_manifest config db request =
  let open Response in
  let id = Dream.param request "manifest_id" in
  let message = Utils.Info.message request in
  Controller.get_manifest_hash ~config ~db ~id >>= function
  | Some hash -> (
      Header.get_if_match request |> function
      | Some etag when hash = etag ->
          Controller.delete_manifest ~config ~db ~id ~message
          >>= delete_manifest
      | None ->
          Controller.delete_manifest ~config ~db ~id
            ~message:(message ^ " no etag")
          >>= delete_manifest
      | _ -> precondition_failed "failed to match etag")
  | None -> not_found "manifest not found"
