open Lwt.Infix

module Git_store_json_value =
  (Irmin_unix.Git.FS.KV)(Irmin.Contents.Json_value)
module Store = Git_store_json_value
module Proj = (Irmin.Json_tree)(Store)

let repository_author = ref "miiify.rocks"

let info message = Irmin_unix.info ~author:!repository_author "%s" message

type t = {db: Store.t Lwt.t }

let create ~fname ~author = 
  repository_author := author;
  let config = Irmin_git.config ~bare:true fname in
  let repo = Store.Repo.v config in
  let branch = repo >>= Store.master in { db = branch }

let add ~ctx ~key ~json ~message =
  ctx.db >>= fun branch -> Proj.set branch key json ~info:(info message)

let get ~ctx ~key = ctx.db >>= fun branch -> Proj.get branch key

let delete ~ctx ~key ~message =
  ctx.db >>= fun branch -> Store.remove_exn branch key ~info:(info message)

let exists ~ctx ~key =
  ctx.db >>= fun branch -> Store.mem_tree branch key

let get_collection ~ctx ~key ~offset ~length =
  ctx.db 
  >>= fun branch -> Store.get_tree branch key 
  >>= fun tree -> Store.Tree.list tree [] ~offset ~length
  >>= Lwt_list.map_s (fun (k, _) -> get ~ctx ~key:(List.append key [k]))
  >|= Ezjsonm.list (fun x -> x)

let count ~ctx ~key =
  ctx.db >>= (fun branch -> (Store.list branch key) >|= List.length)

let get_hash ~ctx ~key =
  ctx.db 
  >>= fun branch -> Store.hash branch key 
  >|= fun hash ->
  match hash with
  | Some(hash) -> Some(Store.Git.Hash.to_hex hash)
  | None -> None