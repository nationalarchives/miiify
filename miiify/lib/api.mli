val get_status : Dream.request -> Dream.response Lwt.t
val get_version : Dream.request -> Dream.response Lwt.t
val get_container : Db.t -> Dream.request -> Dream.response Lwt.t
val get_annotations : int -> Db.t -> Dream.request -> Dream.response Lwt.t
val get_annotation : Db.t -> Dream.request -> Dream.response Lwt.t
