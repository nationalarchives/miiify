val get_id: Dream.client Dream.message -> string

val get_if_none_match: Dream.client Dream.message -> string option

val get_if_match: Dream.client Dream.message -> string option

val get_host: Dream.client Dream.message -> string -> string

val get_prefer: Dream.client Dream.message -> default:string -> string

val param_exists : Dream.request -> string -> bool

val get_page : Dream.request -> int

val get_target : Dream.request -> string option