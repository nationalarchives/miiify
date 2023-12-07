val create :
  data:string ->
  container_id:string ->
  annotation_id:string ->
  host:string ->
  (Yojson.Basic.t, string) result

val update :
  data:string ->
  container_id:string ->
  annotation_id:string ->
  host:string ->
  (Yojson.Basic.t, string) result

val page :
  Yojson.Basic.t ->
  page:int ->
  total:int ->
  limit:int ->
  target:string option ->
  string option

val annotation : Yojson.Basic.t -> string
