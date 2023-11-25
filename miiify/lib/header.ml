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
  | true -> "https://" ^ host
  | false -> "http://" ^ host

let get_host message =
  match Dream.header message "host" with
  | None -> (
      match Dream.header message ":authority" with
      | None -> "https://example.com"
      | Some host -> get_host_helper message host)
  | Some host -> get_host_helper message host

let get_prefer request ~default =
  match Dream.header request "prefer" with
  | None -> default
  | Some
      "return=representation;include=\"http://www.w3.org/ns/ldp#PreferMinimalContainer\""
    ->
      "PreferMinimalContainer"
  | Some
      "return=representation;include=\"http://www.w3.org/ns/oa#PreferContainedIRIs\""
    ->
      "PreferContainedIRIs"
  | Some
      "return=representation;include=\"http://www.w3.org/ns/oa#PreferContainedDescriptions\""
    ->
      "PreferContainedDescriptions"
  | Some v -> v

let param_exists request param =
  match Dream.query request param with None -> false | Some _ -> true

let get_page request =
  match Dream.query request "page" with
  | None -> 0
  | Some page -> (
      match int_of_string_opt page with None -> 0 | Some value -> value)

let get_target request = Dream.query request "target"
