
module Json : sig
  val id_helper : int -> string option -> string
  val filter_null : Yojson.Basic.t -> Yojson.Basic.t
end

module Time : sig
  val get_timestamp : unit -> string
end

module Math : sig
    val calculate_page : int -> int -> int
end