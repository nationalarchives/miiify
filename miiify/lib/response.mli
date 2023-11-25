val ok : string -> Dream.response Lwt.t

val bad_request : string -> Dream.response Lwt.t

val not_found : string -> Dream.response Lwt.t

val not_implemented : string -> Dream.response Lwt.t

val not_modified : string -> Dream.response Lwt.t

val precondition_failed : string -> Dream.response Lwt.t

val create_container : string -> Dream.response Lwt.t

val update_container : string -> Dream.response Lwt.t

val delete_container : unit -> Dream.response Lwt.t

val create_annotation : string -> Dream.response Lwt.t

val update_annotation : string -> Dream.response Lwt.t

val delete_annotation : unit -> Dream.response Lwt.t

val get_collection : hash:string -> string -> Dream.response Lwt.t

val get_page : hash:string -> string -> Dream.response Lwt.t

val get_annotation : hash:string -> string -> Dream.response Lwt.t

val prefer_contained_descriptions : Dream.response Lwt.t -> Dream.response Lwt.t

val prefer_contained_iris : Dream.response Lwt.t -> Dream.response Lwt.t

val prefer_minimal_container : Dream.response Lwt.t -> Dream.response Lwt.t

val get_manifest : hash:string -> string -> Dream.response Lwt.t

val create_manifest : string -> Dream.response Lwt.t

val update_manifest : string -> Dream.response Lwt.t

val delete_manifest : unit -> Dream.response Lwt.t