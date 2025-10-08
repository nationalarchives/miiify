type t

val set_backend : string -> unit

val create : fname:string -> t Lwt.t

val set : db: t -> key:string list -> data:string -> message:string -> unit Lwt.t

val get : db: t -> key:string list -> string Lwt.t

val get_tree : db: t -> key:string list ->  offset:int -> length:int -> string list Lwt.t

val delete : db:t -> key:string list -> message:string -> unit Lwt.t

val get_hash : db: t -> key:string list -> string option Lwt.t

val exists : db:t -> key:string list -> bool Lwt.t

val total : db:t -> key:string list -> int Lwt.t