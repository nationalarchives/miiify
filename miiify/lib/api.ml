(** Simplified read-only view - just serve JSON data *)

open Lwt.Syntax

(* Status endpoint *)
let get_status _request =
  Dream.json {|{"status":"ok"}|}

(* Version endpoint *)
let get_version _request =
  Dream.json {|{"version":"2.0.0","name":"miiify"}|}

(* Get a container (annotation collection) *)
let get_container db request =
  let container_id = Dream.param request "container_id" in
  let* data = Controller.get_container ~db ~container_id in
  Dream.json data

(* Get all annotations in a container with pagination *)
let get_annotations page_limit db request =
  let container_id = Dream.param request "container_id" in
  let page = 
    match Dream.query request "page" with
    | Some p -> (try int_of_string p with _ -> 0)
    | None -> 0
  in
  let* data = Controller.get_annotation_page ~page_limit ~db ~id:container_id ~page ~target:None in
  match data with
  | Some json -> Dream.json json
  | None -> Dream.respond ~status:`Not_Found "Page not found"

(* Get a single annotation *)
let get_annotation db request =
  let container_id = Dream.param request "container_id" in
  let annotation_id = Dream.param request "annotation_id" in
  let* data = Controller.get_annotation ~db ~container_id ~annotation_id in
  Dream.json data
