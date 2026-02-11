(** Simplified read-only view - just serve JSON data *)

open Lwt.Syntax

(* Helper to strip .json extension from slug *)
let strip_json_ext slug =
  if String.length slug > 5 && String.sub slug (String.length slug - 5) 5 = ".json" then
    String.sub slug 0 (String.length slug - 5)
  else
    slug

(* Status endpoint *)
let get_status _request =
  Dream.json {|{"status":"ok"}|}

(* Version endpoint *)
let get_version _request =
  Dream.json {|{"version":"2.0.0","name":"miiify"}|}

(* Get a container (annotation collection) *)
let get_container db request =
  let container_id = Dream.param request "container_id" in
  let* hash_opt = Model.get_container_hash ~db ~container_id in
  let etag = Option.map (fun h -> "\"" ^ h ^ "\"") hash_opt in
  
  (* Check If-None-Match *)
  let if_none_match = Dream.header request "If-None-Match" in
  match (etag, if_none_match) with
  | (Some tag, Some client_tag) when tag = client_tag ->
      Dream.respond ~status:`Not_Modified ""
  | _ ->
      let* data = Controller.get_container ~db ~container_id in
      let* response = Dream.json data in
      (match etag with
      | Some tag -> Dream.add_header response "ETag" tag
      | None -> ());
      Lwt.return response

(* Get all annotations in a container with pagination *)
let get_annotations page_limit db request =
  let container_id = Dream.param request "container_id" in
  let page = 
    match Dream.query request "page" with
    | Some p -> (try int_of_string p with _ -> 0)
    | None -> 0
  in
  let* hash_opt = Model.get_collection_hash ~db ~container_id in
  let etag = Option.map (fun h -> "\"" ^ h ^ "\"") hash_opt in
  
  (* Check If-None-Match *)
  let if_none_match = Dream.header request "If-None-Match" in
  match (etag, if_none_match) with
  | (Some tag, Some client_tag) when tag = client_tag ->
      Dream.respond ~status:`Not_Modified ""
  | _ ->
      let* data = Controller.get_annotation_page ~page_limit ~db ~id:container_id ~page ~target:None in
      match data with
      | Some json -> 
          let* response = Dream.json json in
          (match etag with
          | Some tag -> Dream.add_header response "ETag" tag
          | None -> ());
          Lwt.return response
      | None -> Dream.respond ~status:`Not_Found "Page not found"

(* Get a single annotation *)
let get_annotation db request =
  let container_id = Dream.param request "container_id" in
  let annotation_id = Dream.param request "annotation_id" |> strip_json_ext in
  let* hash_opt = Model.get_annotation_hash ~db ~container_id ~annotation_id in
  let etag = Option.map (fun h -> "\"" ^ h ^ "\"") hash_opt in
  
  (* Check If-None-Match *)
  let if_none_match = Dream.header request "If-None-Match" in
  match (etag, if_none_match) with
  | (Some tag, Some client_tag) when tag = client_tag ->
      Dream.respond ~status:`Not_Modified ""
  | _ ->
      let* data = Controller.get_annotation ~db ~container_id ~annotation_id in
      let* response = Dream.json data in
      (match etag with
      | Some tag -> Dream.add_header response "ETag" tag
      | None -> ());
      Lwt.return response
