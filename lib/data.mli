
val post_annotation :
  data:string -> id:string list -> host:string -> (Ezjsonm.value, string) result

val post_container :
  data:string -> id:string list -> host:string -> (Ezjsonm.value, string) result

val put_annotation :
  data:string -> id:string list -> host:string -> (Ezjsonm.value, string) result

val post_manifest :
  data:string -> (Ezjsonm.value, string) result  

val put_manifest :
  data:string -> (Ezjsonm.value, string) result   

