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
    if limit <= 0 then 0
    else int_of_float (Float.ceil (float_of_int total /. float_of_int limit)) - 1
end

module Validation : sig
  val is_valid_container_name : string -> bool
  val is_valid_json_file : string -> bool
  val validate_basic_json : string -> (unit, string) result
  val validate_annotation : string -> (unit, string) result
  val reject_top_level_id : string -> (unit, string) result
  val validate_path : string list -> (unit, string) result
end = struct
  let is_valid_container_name name =
    (* Container names must be URL-safe: alphanumeric, hyphens, underscores *)
    let length = String.length name in
    length > 0 && length <= 255 &&
    String.for_all (fun c ->
      (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c = '-' || c = '_'
    ) name

  let is_valid_json_file filename =
    (* Must end with .json and not be hidden *)
    String.ends_with ~suffix:".json" filename &&
    not (String.starts_with ~prefix:"." filename)

  let validate_basic_json content =
    (* Check if content is at least parseable as JSON *)
    try
      let _ = Yojson.Basic.from_string content in
      Ok ()
    with
    | Yojson.Json_error msg -> Error ("Invalid JSON: " ^ msg)
    | e -> Error ("Parse error: " ^ Printexc.to_string e)

  let validate_annotation content =
    try
      let _ = Specification_j.specification_of_string content in
      Ok ()
    with
    | Yojson.Json_error msg -> Error ("JSON parse error: " ^ msg)
    | Atdgen_runtime.Oj_run.Error msg -> Error ("Schema validation error: " ^ msg)
    | e -> Error ("Validation error: " ^ Printexc.to_string e)

  let reject_top_level_id content =
    (* IDs are derived from --base-url and the file path; they must not be stored. *)
    try
      let json = Yojson.Basic.from_string content in
      match Yojson.Basic.Util.member "id" json with
      | `Null -> Ok ()
      | _ -> Error "an 'id' field can not be supplied"
    with
    | _ -> Ok ()

  let validate_path path =
    (* Validate structure: must be <container>/main or <container>/collection/<slug> *)
    match path with
    | [] -> Error "Empty path"
    | [container; "main"] ->
        if is_valid_container_name container then Ok ()
        else Error (Printf.sprintf "Invalid container name '%s' (use only a-z, A-Z, 0-9, -, _)" container)
    | [container; "collection"; slug] ->
        if not (is_valid_container_name container) then
          Error (Printf.sprintf "Invalid container name '%s' (use only a-z, A-Z, 0-9, -, _)" container)
        else if String.length slug = 0 then
          Error "Empty annotation slug"
        else
          Ok ()
    | _ -> Error (Printf.sprintf "Invalid path structure: %s (must be <container>/main or <container>/collection/<slug>)" (String.concat "/" path))
end
