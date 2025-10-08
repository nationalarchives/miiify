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

module File : sig
  val read_file : string -> string
end = struct
  let read_file filename =
    let ch = open_in filename in
    let s = really_input_string ch (in_channel_length ch) in
    close_in ch;
    s
end

module Time : sig
  val get_timestamp : unit -> string
end = struct
  let get_timestamp () =
    let t = Ptime_clock.now () in
    Ptime.to_rfc3339 t ~tz_offset_s:0
end

module Cmd : sig
  val parse : unit -> Config_t.config
end = struct
  let config_file = ref "config.json"

  let parse_worker () =
    let usage = "usage: " ^ Sys.argv.(0) in
    let speclist =
      [
        ( "--config",
          Arg.Set_string config_file,
          ": to specify the configuration file to use" );
      ]
    in
    Arg.parse speclist (fun x -> raise (Arg.Bad ("Bad argument : " ^ x))) usage

  let parse () =
    let () = parse_worker () in
    let data = File.read_file !config_file in
    match Config.parse ~data with
    | Error message -> failwith message
    | Ok config -> 
        (* Override backend from environment variable if set *)
        let backend = match Sys.getenv_opt "MIIIFY_BACKEND" with
          | Some env_backend -> env_backend
          | None -> config.backend
        in
        { config with backend }
end

module Math : sig
  val calculate_page : int -> int -> int
end = struct
  let calculate_page total limit =
    int_of_float (Float.ceil (float_of_int total /. float_of_int limit)) - 1
end

module Info : sig
  val message : Dream.request -> string
end = struct
  let message request =
    let client = Dream.client request in
    let method_ = Dream.method_ request in
    Printf.sprintf "%s %s" (Dream.method_to_string method_) client
end
