(* from https://github.com/ocaml-community/yojson/issues/54 *)
module Json : sig
  val id_helper : int -> string option -> string
  val filter_null : Yojson.Basic.t -> Yojson.Basic.t
end = struct
  let id_helper page target =
    let open Printf in
    match target with
    | Some target -> sprintf "?page=%d&target=%s" page target
    | None -> sprintf "?page=%d" page

  let filter_null json =
    let open Yojson.Basic in
    Util.to_assoc json |> List.filter (fun (_, v) -> v != `Null) |> fun v ->
    `Assoc v
end

module Time : sig
  val get_timestamp : unit -> string
end = struct
  let get_timestamp () =
    let t = Ptime_clock.now () in
    Ptime.to_rfc3339 t ~tz_offset_s:0
end

module Math : sig
  val calculate_page : int -> int -> int
end = struct
  let calculate_page total limit =
    int_of_float (Float.ceil (float_of_int total /. float_of_int limit)) - 1
end
