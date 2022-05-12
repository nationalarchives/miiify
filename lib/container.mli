type t

val create : page_limit:int -> representation:string -> t

val annotation_page :
  ctx:t ->
    db:Db.t -> key:string list -> page:int -> Ezjsonm.value option Lwt.t

val annotation_collection :
  ctx:t -> db:Db.t -> key:string list -> Ezjsonm.value Lwt.t

val get_representation : ctx:t -> string

val set_representation : ctx:t -> representation:string -> unit

val modify_timestamp : db:Db.t -> container_id:string -> unit Lwt.t