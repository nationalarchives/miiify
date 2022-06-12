type t

val post_annotation :
  data:string -> id:string list -> host:string -> (t, string) result

val post_container :
  data:string -> id:string list -> host:string -> (t, string) result

val put_annotation :
  data:string -> id:string list -> host:string -> (t, string) result

val post_manifest :
  data:string -> id:string list -> (t, string) result  

val put_manifest :
  data:string -> id:string list -> (t, string) result   

val id : t -> string list
val json : t -> Ezjsonm.value
val to_string : t -> string
