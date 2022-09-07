type t

val create : page_limit:int -> representation:string -> t
val get_representation : ctx:t -> string
val set_representation : ctx:t -> representation:string -> unit

val get_annotation_page
  :  ctx:t
  -> db:Db.t
  -> key:string list
  -> page:int
  -> target:string option
  -> Ezjsonm.value option Lwt.t

val get_annotation_collection : ctx:t -> db:Db.t -> key:string list -> Ezjsonm.value Lwt.t
val get_annotation : db:Db.t -> key:string list -> Ezjsonm.value Lwt.t

val add_annotation
  :  db:Db.t
  -> key:string list
  -> json:Ezjsonm.value
  -> message:string
  -> unit Lwt.t

val update_annotation
  :  db:Db.t
  -> key:string list
  -> json:Ezjsonm.value
  -> message:string
  -> unit Lwt.t

val delete_annotation : db:Db.t -> key:string list -> message:string -> unit Lwt.t

val add_container
  :  db:Db.t
  -> key:string list
  -> json:Ezjsonm.value
  -> message:string
  -> unit Lwt.t

val delete_container : db:Db.t -> key:string list -> message:string -> unit Lwt.t
val get_hash : db:Db.t -> key:string list -> string option Lwt.t
val container_exists : db:Db.t -> key:string list -> bool Lwt.t
val annotation_exists : db:Db.t -> key:string list -> bool Lwt.t
val get_page : Dream.request -> int
val get_target : Dream.request -> string option
