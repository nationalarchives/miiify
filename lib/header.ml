let gen_uuid () =
  Uuidm.v4_gen (Random.State.make_self_init ()) () |> Uuidm.to_string

let get_id message =
  match Dream.header message "Slug" with
  | None -> gen_uuid ()
  | Some slug -> slug

let get_if_none_match message = Dream.header message "If-None-Match"
let get_if_match message = Dream.header message "If-Match"

let get_host_helper request host =
  match Dream.tls request with
  | true -> Some ("https://" ^ host)
  | false -> Some ("http://" ^ host)

let get_host message =
  match Dream.header message "host" with
  | None -> (
      match Dream.header message ":authority" with
      | None -> None
      | Some host -> get_host_helper message host)
  | Some host -> get_host_helper message host

let process_representation prefer =
  let lis = String.split_on_char ' ' prefer in
  List.map (fun x -> String.split_on_char '#' x) lis

let strip_last_char str =
  if str = "" then "" else String.sub str 0 (String.length str - 1)

let get_prefer message default =
  match Dream.header message "prefer" with
  | None -> default
  | Some prefer -> (
      match process_representation prefer with
      | [ _; x ] :: _ -> strip_last_char x
      | _ -> default)
