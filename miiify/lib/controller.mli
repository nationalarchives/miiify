val get_container : db:Db.t -> container_id:string -> string Lwt.t

val post_container :
  db:Db.t ->
  id:string ->
  host:string ->
  message:string ->
  string ->
  (string Lwt.t, string) result Lwt.t

val put_container :
  db:Db.t ->
  id:string ->
  host:string ->
  message:string ->
  string ->
  (string Lwt.t, string) result Lwt.t

val delete_container : db:Db.t -> id:string -> message:string -> unit Lwt.t

val post_annotation :
  db:Db.t ->
  container_id:string ->
  annotation_id:string ->
  host:string ->
  message:string ->
  string ->
  (string Lwt.t, string) result Lwt.t

val put_annotation :
  db:Db.t ->
  container_id:string ->
  annotation_id:string ->
  host:string ->
  message:string ->
  string ->
  (string Lwt.t, string) result Lwt.t

val container_exists : db:Db.t -> id:string -> bool Lwt.t

val annotation_exists :
  db:Db.t -> container_id:string -> annotation_id:string -> bool Lwt.t

val get_annotation :
  db:Db.t -> container_id:string -> annotation_id:string -> string Lwt.t

val delete_annotation :
  db:Db.t ->
  container_id:string ->
  annotation_id:string ->
  message:string ->
  unit Lwt.t

val get_collection_hash : db:Db.t -> id:string -> string option Lwt.t
val get_container_hash : db:Db.t -> id:string -> string option Lwt.t

val get_annotation_hash :
  db:Db.t -> container_id:string -> annotation_id:string -> string option Lwt.t

val get_annotation_collection :
  config:Config_t.config ->
  db:Db.t ->
  id:string ->
  target:string option ->
  string Lwt.t

val get_annotation_page :
  config:Config_t.config ->
  db:Db.t ->
  id:string ->
  page:int ->
  target:string option ->
  string option Lwt.t

val get_manifest : db:Db.t -> id:string -> string Lwt.t

val post_manifest :
  db:Db.t ->
  id:string ->
  message:string ->
  string ->
  (string Lwt.t, string) result Lwt.t

val put_manifest :
  db:Db.t ->
  id:string ->
  message:string ->
  string ->
  (string Lwt.t, string) result Lwt.t

val delete_manifest : db:Db.t -> id:string -> message:string -> unit Lwt.t
val manifest_exists : db:Db.t -> id:string -> bool Lwt.t
val get_manifest_hash : db:Db.t -> id:string -> string option Lwt.t
