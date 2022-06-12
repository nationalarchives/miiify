val get_manifest : db:Db.t -> key:string list -> Ezjsonm.value Lwt.t

val add_manifest : db:Db.t -> key:string list -> json:Ezjsonm.value -> message:string -> unit Lwt.t

val update_manifest : db:Db.t -> key:string list -> json:Ezjsonm.value -> message:string -> unit Lwt.t

val delete_manifest : db:Db.t ->  key:string list -> message:string -> unit Lwt.t

val manifest_exists : db:Db.t -> key:string list -> bool Lwt.t

val get_hash : db:Db.t ->  key:string list -> string option Lwt.t
