val status : Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t
val version : Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val post_container :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val put_container :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val delete_container :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val post_annotation :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val put_annotation :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val get_annotation :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val delete_annotation :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val get_container :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val post_manifest :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val get_manifest :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val put_manifest :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t

val delete_manifest :
  Config_t.config -> Db.t -> Dream.request -> Dream.response Lwt.t
