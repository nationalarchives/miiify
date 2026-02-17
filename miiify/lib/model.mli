val create : repository_name:string -> Db.t Lwt.t

val get_container : db:Db.t -> container_id:string -> Yojson.Basic.t Lwt.t

val get_annotations :
  db:Db.t ->
  container_id:string ->
  offset:int ->
  length:int ->
  (Yojson.Basic.t * (string * Yojson.Basic.t) list * Yojson.Basic.t) Lwt.t

val get_annotation :
  db:Db.t -> container_id:string -> annotation_id:string -> Yojson.Basic.t Lwt.t

val get_annotation_hash :
  db:Db.t -> container_id:string -> annotation_id:string -> string option Lwt.t

val container_exists : db:Db.t -> container_id:string -> bool Lwt.t

val annotation_exists :
  db:Db.t -> container_id:string -> annotation_id:string -> bool Lwt.t

val get_collection_hash : db:Db.t -> container_id:string -> string option Lwt.t
val get_container_hash : db:Db.t -> container_id:string -> string option Lwt.t
val total : db:Db.t -> container_id:string -> int Lwt.t