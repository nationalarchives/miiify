open Lwt
open Lwt.Syntax

module Store = Irmin_git_unix.FS.KV (Irmin.Contents.String)
module Store_info = Irmin_unix.Info (Store.Info)

let info message = Store_info.v ~author:"miiify.rocks" "%s" message

type t = Store.t Lwt.t

let create ~fname =
  let config = Irmin_git.config ~bare:true fname in
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
  let* items = Store.Tree.list tree [] ~offset ~length in
  let sorted_items = List.sort (fun (k1, _) (k2, _) -> String.compare k1 k2) items in
  Lwt_list.map_s (fun (k, _) -> get ~db ~key:(List.append key [ k ])) sorted_items

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
  let* exists = Store.mem_tree store key in
  if exists then
    let+ list = Store.list store key in
    List.length list
  else
    Lwt.return 0

