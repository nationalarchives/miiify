val create :
  data:string -> id:string -> host:string -> (Yojson.Basic.t, string) result

val update :
  data:string -> id:string -> host:string -> (Yojson.Basic.t, string) result

val collection :
  Yojson.Basic.t -> total:int -> limit:int -> target:string option -> string

val container : Yojson.Basic.t -> string
