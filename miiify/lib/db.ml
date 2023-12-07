open Lwt
open Lwt.Syntax

module Conf = struct
  let entries = 32
  let stable_hash = 256
  let contents_length_header = Some `Varint
  let inode_child_order = `Seeded_hash
  let forbid_empty_dir_persistence = false
end

module Repo_config = struct
  let readonly = false
  let index_log_size = 2_500_000
  let merge_throttle = `Block_writes
  let indexing_strategy = Irmin_pack.Indexing_strategy.minimal
  let fresh = false

  let config =
    Irmin_pack.config ~fresh ~index_log_size ~merge_throttle ~indexing_strategy
      ~readonly
end

module StoreMaker = Irmin_pack_unix.KV (Conf)
module Store = StoreMaker.Make (Irmin.Contents.String)
module Store_info = Irmin_unix.Info (Store.Info)

let info message = Store_info.v ~author:"miiify.rocks" "%s" message

type t = Store.t Lwt.t

let create ~fname =
  let config = Repo_config.config fname in
  let repo = Store.Repo.v config in
  let* repo = repo in
  Store.main repo

let set ~db ~key ~data ~message =
  let* store = db in
  Store.set_exn store key data ~info:(info message)

let get ~db ~key =
  let* store = db in
  Store.get store key

let get_tree ~db ~key ~offset ~length =
  let* store = db in
  let* tree = Store.get_tree store key in
  Store.Tree.list tree [] ~offset ~length
  >>= Lwt_list.map_s (fun (k, _) -> get ~db ~key:(List.append key [ k ]))

let delete ~db ~key ~message =
  let* store = db in
  Store.remove_exn store key ~info:(info message)

let to_base64 hash =
  let s = Store.Hash.to_raw_string hash in
  Base64.encode_exn s

let get_hash ~db ~key =
  let* store = db in
  Store.hash store key >|= function
  | Some hash -> Some (to_base64 hash)
  | None -> None

let exists ~db ~key =
  let* store = db in
  Store.mem_tree store key

let total ~db ~key =
  let* store = db in
  let* tree = Store.get_tree store key in
  Store.Tree.length tree []
