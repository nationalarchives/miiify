(** Simplified read-only view - just serve JSON data *)

open Lwt.Syntax

let make_etag hash parts =
  let suffix =
    parts
    |> List.filter_map (fun (k, v_opt) ->
           match v_opt with
           | None -> None
           | Some v -> Some (";" ^ k ^ "=" ^ v))
    |> String.concat ""
  in
  "\"" ^ hash ^ suffix ^ "\""

let percent_opt = function
  | None -> None
  | Some v -> Some (Dream.to_percent_encoded v)

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
  let json = Printf.sprintf {|{"version":"%s","name":"%s"}|} Version.version Version.name in
  Dream.json json

(* Get a container (annotation collection) *)
let get_container base_url db request =
  let container_id = Dream.param request "container_id" in
  let* exists = Model.container_exists ~db ~container_id in
  if not exists then Dream.respond ~status:`Not_Found "Container not found"
  else
  let* hash_opt = Model.get_container_hash ~db ~container_id in
  let etag = Option.map (fun h -> "\"" ^ h ^ "\"") hash_opt in
  
  (* Check If-None-Match *)
  let if_none_match = Dream.header request "If-None-Match" in
  match (etag, if_none_match) with
  | (Some tag, Some client_tag) when tag = client_tag ->
      Dream.respond ~status:`Not_Modified ""
  | _ ->
      Lwt.catch
        (fun () ->
          let* data = Controller.get_container ~db ~container_id ~base_url in
          let* response = Dream.json data in
          (match etag with
          | Some tag -> Dream.add_header response "ETag" tag
          | None -> ());
          Lwt.return response)
        (fun _exn -> Dream.respond ~status:`Internal_Server_Error "Internal server error")

(* Get AnnotationCollection with embedded first page *)
let get_annotation_collection base_url page_limit db request =
  let container_id = Dream.param request "container_id" in
  let target = Dream.query request "target" in
  
  let* exists = Model.container_exists ~db ~container_id in
  if not exists then
    Dream.respond ~status:`Not_Found "Container not found"
  else
  
  let* hash_opt = Model.get_collection_hash ~db ~container_id in
  let etag =
    Option.map
      (fun h ->
        make_etag h
          [ ("limit", Some (string_of_int page_limit));
            ("target", percent_opt target) ])
      hash_opt
  in
  
  let if_none_match = Dream.header request "If-None-Match" in
  (match (etag, if_none_match) with
  | (Some tag, Some client_tag) when tag = client_tag ->
      Dream.respond ~status:`Not_Modified ""
  | _ ->
      Lwt.catch
        (fun () ->
          let* data = Controller.get_annotation_collection ~page_limit ~db ~id:container_id ~target ~base_url in
          let* response = Dream.json data in
          (match etag with
          | Some tag -> Dream.add_header response "ETag" tag
          | None -> ());
          Lwt.return response)
        (fun _exn -> Dream.respond ~status:`Internal_Server_Error "Internal server error"))

(* Get AnnotationPage with items *)
let get_annotation_page base_url page_limit db request =
  let container_id = Dream.param request "container_id" in
  let target = Dream.query request "target" in
  let page_str = Dream.query request "page" |> Option.value ~default:"0" in
  let page = try int_of_string page_str with _ -> 0 in
  
  let* exists = Model.container_exists ~db ~container_id in
  if not exists then
    Dream.respond ~status:`Not_Found "Container not found"
  else
  
  let* hash_opt = Model.get_collection_hash ~db ~container_id in
  let etag =
    Option.map
      (fun h ->
        make_etag h
          [ ("limit", Some (string_of_int page_limit));
            ("page", Some (string_of_int page));
            ("target", percent_opt target) ])
      hash_opt
  in
  
  let if_none_match = Dream.header request "If-None-Match" in
  (match (etag, if_none_match) with
  | (Some tag, Some client_tag) when tag = client_tag ->
      Dream.respond ~status:`Not_Modified ""
  | _ ->
      Lwt.catch
        (fun () ->
          let* data = Controller.get_annotation_page ~page_limit ~db ~id:container_id ~page ~target ~base_url in
          match data with
          | Some json -> 
              let* response = Dream.json json in
              (match etag with
              | Some tag -> Dream.add_header response "ETag" tag
              | None -> ());
              Lwt.return response
          | None -> Dream.respond ~status:`Not_Found "Page not found")
        (fun _exn -> Dream.respond ~status:`Internal_Server_Error "Internal server error"))

(* Dispatcher: route to collection or page based on query parameter *)
let get_annotations base_url page_limit db request =
  match Dream.query request "page" with
  | None -> get_annotation_collection base_url page_limit db request
  | Some _ -> get_annotation_page base_url page_limit db request

(* Get a single annotation *)
let get_annotation base_url db request =
  let container_id = Dream.param request "container_id" in
  let annotation_id = Dream.param request "annotation_id" |> strip_json_ext in
  let* exists = Model.annotation_exists ~db ~container_id ~annotation_id in
  if not exists then Dream.respond ~status:`Not_Found "Annotation not found"
  else
  let* hash_opt = Model.get_annotation_hash ~db ~container_id ~annotation_id in
  let etag = Option.map (fun h -> "\"" ^ h ^ "\"") hash_opt in
  
  (* Check If-None-Match *)
  let if_none_match = Dream.header request "If-None-Match" in
  match (etag, if_none_match) with
  | (Some tag, Some client_tag) when tag = client_tag ->
      Dream.respond ~status:`Not_Modified ""
  | _ ->
      Lwt.catch
        (fun () ->
          let* data = Controller.get_annotation ~db ~container_id ~annotation_id ~base_url in
          let* response = Dream.json data in
          (match etag with
          | Some tag -> Dream.add_header response "ETag" tag
          | None -> ());
          Lwt.return response)
        (fun _exn -> Dream.respond ~status:`Internal_Server_Error "Internal server error")
