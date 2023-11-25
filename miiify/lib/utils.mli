
module Json : sig
  val id_helper : int -> string option -> string
  val filter_null : Yojson.Basic.t -> Yojson.Basic.t
end

module File : sig
  val read_file : string -> string
end

module Time : sig
  val get_timestamp : unit -> string
end

module Cmd : sig
  val parse : unit -> Config_t.config
end

module Math : sig
    val calculate_page : int -> int -> int
end

module Info : sig
  val message : Dream.request -> string
end