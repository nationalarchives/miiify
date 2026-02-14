val page :
  Yojson.Basic.t ->
  page:int ->
  total:int ->
  limit:int ->
  target:string option ->
  string option

val annotation : Yojson.Basic.t -> string

val inject_id : Yojson.Basic.t -> container_id:string -> annotation_id:string -> base_url:string -> Yojson.Basic.t
