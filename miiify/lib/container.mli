val collection :
  Yojson.Basic.t -> total:int -> limit:int -> string

val container : Yojson.Basic.t -> string

val inject_id : Yojson.Basic.t -> container_id:string -> base_url:string -> Yojson.Basic.t
