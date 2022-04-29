type t

val create : fname:string -> author:string -> t

val add :
  ctx:t -> key:string list -> json:Ezjsonm.value -> message:string -> unit Lwt.t

val get : ctx:t -> key:string list -> Ezjsonm.value Lwt.t
val delete : ctx:t -> key:string list -> message:string -> unit Lwt.t
val exists : ctx:t -> key:string list -> bool Lwt.t

val get_collection :
  ctx:t -> key:string list -> offset:int -> length:int -> Ezjsonm.value Lwt.t

val count : ctx:t -> key:string list -> int Lwt.t
val get_hash : ctx:t -> key:string list -> string option Lwt.t
