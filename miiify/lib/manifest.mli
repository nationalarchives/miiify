val create :
  data:string -> (Yojson.Basic.t, string) result

val update :
  data:string -> (Yojson.Basic.t, string) result

val manifest : Yojson.Basic.t -> string
