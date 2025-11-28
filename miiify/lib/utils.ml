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
  module EnvOverride = struct
    let string name default =
      match Sys.getenv_opt name with
      | Some v -> v
      | None -> default
      
    let int name default =
      match Sys.getenv_opt name with
      | Some v -> (try int_of_string v with _ -> default)
      | None -> default
      
    let bool name default =
      match Sys.getenv_opt name with
      | Some v -> (
          match String.lowercase_ascii v with
          | "true" | "1" | "yes" -> true
          | "false" | "0" | "no" -> false
          | _ -> default
        )
      | None -> default
  end

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
        { config with
          backend = EnvOverride.string "MIIIFY_BACKEND" config.backend;
          port = EnvOverride.int "MIIIFY_PORT" config.port;
          interface = EnvOverride.string "MIIIFY_INTERFACE" config.interface;
          tls = EnvOverride.bool "MIIIFY_TLS" config.tls;
          id_proto = EnvOverride.string "MIIIFY_ID_PROTO" config.id_proto;
          certificate_file = EnvOverride.string "MIIIFY_CERTIFICATE_FILE" config.certificate_file;
          key_file = EnvOverride.string "MIIIFY_KEY_FILE" config.key_file;
          repository_name = EnvOverride.string "MIIIFY_REPOSITORY_NAME" config.repository_name;
          container_page_limit = EnvOverride.int "MIIIFY_CONTAINER_PAGE_LIMIT" config.container_page_limit;
          access_control_allow_origin = EnvOverride.string "MIIIFY_ACCESS_CONTROL_ALLOW_ORIGIN" config.access_control_allow_origin;
          validate_annotation = EnvOverride.bool "MIIIFY_VALIDATE_ANNOTATION" config.validate_annotation;
        }
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
