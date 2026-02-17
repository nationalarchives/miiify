
module Json : sig
  val id_helper : int -> string
  val filter_null : Yojson.Basic.t -> Yojson.Basic.t
end

module Time : sig
  val get_timestamp : unit -> string
end

module Math : sig
    val calculate_page : int -> int -> int
end
module Validation : sig
  val is_valid_container_name : string -> bool
  val is_valid_json_file : string -> bool
  val validate_basic_json : string -> (unit, string) result
  val validate_annotation : string -> (unit, string) result
  val validate_path : string list -> (unit, string) result
end
