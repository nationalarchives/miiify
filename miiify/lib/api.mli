val get_status : Dream.request -> Dream.response Lwt.t
val get_version : Dream.request -> Dream.response Lwt.t
val get_annotations : string -> int -> Db.t -> Dream.request -> Dream.response Lwt.t
val get_annotation : string -> Db.t -> Dream.request -> Dream.response Lwt.t
