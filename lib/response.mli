val json_response: request:Dream.request ->
    body:Ezjsonm.value -> ?etag:string option -> unit -> Dream.response Lwt.t

val error_response: Dream.status -> string -> Dream.response Lwt.t

val options_response: string list -> Dream.response Lwt.t

val html_response: string -> Dream.request -> Dream.response Lwt.t

val empty_response: Dream.status -> Dream.response Lwt.t