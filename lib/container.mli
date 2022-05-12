type t

val create : page_limit:int -> representation:string -> t

val annotation_page :
  ctx:t ->
    db:Db.t -> key:string list -> page:int -> Ezjsonm.value option Lwt.t

val annotation_collection :
  ctx:t -> db:Db.t -> key:string list -> Ezjsonm.value Lwt.t

val get_representation : ctx:t -> string

val set_representation : ctx:t -> representation:string -> unit

val add_annotation : db:Db.t -> key:string list -> container_id:string -> json:Ezjsonm.value -> message:string -> unit Lwt.t

val add_container : db:Db.t -> key:string list -> json:Ezjsonm.value -> message:string -> unit Lwt.t

val delete_annotation : db:Db.t ->  key:string list -> container_id:string -> message:string -> unit Lwt.t

val delete_container : db:Db.t ->  key:string list -> message:string -> unit Lwt.t

val hash : db:Db.t ->  key:string list -> string option Lwt.t
