val get_status : Config_t.config -> Dream.request -> Dream.response Lwt.t
val get_version : Config_t.config -> Dream.request -> Dream.response Lwt.t
val get_container : Db.t -> Dream.request -> Dream.response Lwt.t
val post_container : Db.t -> Dream.request -> Dream.response Lwt.t

val put_container :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val delete_container :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val post_annotation : Db.t -> Dream.request -> Dream.response Lwt.t

val put_annotation :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val get_annotation : Db.t -> Dream.request -> Dream.response Lwt.t

val delete_annotation :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val get_annotations :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val post_manifest : Db.t -> Dream.request -> Dream.response Lwt.t
val get_manifest : Db.t -> Dream.request -> Dream.response Lwt.t

val put_manifest :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val delete_manifest :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t
