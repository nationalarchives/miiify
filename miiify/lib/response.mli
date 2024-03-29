val status : string -> Dream.response Lwt.t
val options_status : Dream.response Lwt.t
val version : string -> Dream.response Lwt.t
val options_version : Dream.response Lwt.t
val bad_request : string -> Dream.response Lwt.t
val internal_server_error : string -> Dream.response Lwt.t
val not_found : string -> Dream.response Lwt.t
val not_implemented : string -> Dream.response Lwt.t
val not_modified : string -> Dream.response Lwt.t
val precondition_failed : string -> Dream.response Lwt.t
val options_container : Dream.response Lwt.t
val options_create_container : Dream.response Lwt.t
val get_container : hash:string -> string -> Dream.response Lwt.t
val create_container : string -> Dream.response Lwt.t
val update_container : string -> Dream.response Lwt.t
val delete_container : unit -> Dream.response Lwt.t
val create_annotation : string -> Dream.response Lwt.t
val update_annotation : string -> Dream.response Lwt.t
val delete_annotation : unit -> Dream.response Lwt.t
val options_annotations : Dream.response Lwt.t
val get_collection : hash:string -> string -> Dream.response Lwt.t
val get_page : hash:string -> string -> Dream.response Lwt.t
val options_annotation : Dream.response Lwt.t
val get_annotation : hash:string -> string -> Dream.response Lwt.t
val get_manifest : hash:string -> string -> Dream.response Lwt.t
val create_manifest : string -> Dream.response Lwt.t
val update_manifest : string -> Dream.response Lwt.t
val delete_manifest : unit -> Dream.response Lwt.t
val options_manifest : Dream.response Lwt.t
val head : Dream.server Dream.message -> Dream.response Lwt.t

val from_json :
  status:Dream.status ->
  headers:(string * string) list ->
  Yojson.Basic.t ->
  Dream.response Lwt.t
