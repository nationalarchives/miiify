val get_container : db:Db.t -> container_id:string -> base_url:string -> string Lwt.t
val container_exists : db:Db.t -> id:string -> bool Lwt.t

val annotation_exists :
  db:Db.t -> container_id:string -> annotation_id:string -> bool Lwt.t

val get_annotation :
  db:Db.t -> container_id:string -> annotation_id:string -> base_url:string -> string Lwt.t

val get_collection_hash : db:Db.t -> id:string -> string option Lwt.t
val get_container_hash : db:Db.t -> id:string -> string option Lwt.t

val get_annotation_hash :
  db:Db.t -> container_id:string -> annotation_id:string -> string option Lwt.t

val get_annotation_collection :
  page_limit:int ->
  db:Db.t ->
  id:string ->
  target:string option ->
  base_url:string ->
  string Lwt.t

val get_annotation_page :
  page_limit:int ->
  db:Db.t ->
  id:string ->
  page:int ->
  target:string option ->
  base_url:string ->
  string option Lwt.t

(* Manifest functions removed - not used in simplified read-only API *)
