val create : config:Config_t.config -> Db.t

val get_container : db:Db.t -> container_id:string -> Yojson.Basic.t Lwt.t

val get_annotations :
  db:Db.t ->
  container_id:string ->
  offset:int ->
  length:int ->
  target:string option ->
  Yojson.Basic.t Lwt.t

val get_annotation :
  db:Db.t -> container_id:string -> annotation_id:string -> Yojson.Basic.t Lwt.t

val get_annotation_hash :
  db:Db.t -> container_id:string -> annotation_id:string -> string option Lwt.t

val delete_annotation :
  db:Db.t ->
  container_id:string ->
  annotation_id:string ->
  message:string ->
  unit Lwt.t

val add_container :
  db:Db.t ->
  container_id:string ->
  json:Yojson.Basic.t ->
  message:string ->
  string Lwt.t

val update_container :
  db:Db.t ->
  container_id:string ->
  json:Yojson.Basic.t ->
  message:string ->
  string Lwt.t

val delete_container :
  db:Db.t -> container_id:string -> message:string -> unit Lwt.t

val add_annotation :
  db:Db.t ->
  container_id:string ->
  annotation_id:string ->
  json:Yojson.Basic.t ->
  message:string ->
  string Lwt.t

val update_annotation :
  db:Db.t ->
  container_id:string ->
  annotation_id:string ->
  json:Yojson.Basic.t ->
  message:string ->
  string Lwt.t

val container_exists : db:Db.t -> container_id:string -> bool Lwt.t

val annotation_exists :
  db:Db.t -> container_id:string -> annotation_id:string -> bool Lwt.t

val get_collection_hash : db:Db.t -> container_id:string -> string option Lwt.t
val get_container_hash : db:Db.t -> container_id:string -> string option Lwt.t
val total : db:Db.t -> container_id:string -> int Lwt.t

val get_manifest : db:Db.t -> manifest_id:string -> Yojson.Basic.t Lwt.t

val add_manifest :
  db:Db.t ->
  manifest_id:string ->
  json:Yojson.Basic.t ->
  message:string ->
  string Lwt.t

val update_manifest :
  db:Db.t ->
  manifest_id:string ->
  json:Yojson.Basic.t ->
  message:string ->
  string Lwt.t

val delete_manifest :
  db:Db.t -> manifest_id:string -> message:string -> unit Lwt.t

val manifest_exists : db:Db.t -> manifest_id:string -> bool Lwt.t

val get_manifest_hash : db:Db.t -> manifest_id:string -> string option Lwt.t