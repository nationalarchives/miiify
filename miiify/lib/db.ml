(* Pack backend implementation *)
module Pack = Storage_pack

(* Git backend implementation *)
module Git = Storage_git

(* Unified database type that can hold either backend *)
type t = 
  | Pack_db of Pack.t
  | Git_db of Git.t

(* Current backend selection - set by configuration *)
let current_backend = ref "pack"

let set_backend backend = current_backend := backend

(* Dynamic dispatch functions *)
let create ~fname =
  match !current_backend with
  | "pack" -> Lwt.return (Pack_db (Pack.create ~fname))
  | "git" -> Lwt.return (Git_db (Git.create ~fname))
  | backend -> failwith ("Unknown backend: " ^ backend)

let set ~db ~(key : string list) ~data ~message =
  match db with
  | Pack_db pack_db -> Pack.set ~db:pack_db ~key ~data ~message
  | Git_db git_db -> Git.set ~db:git_db ~key ~data ~message

let get ~db ~(key : string list) =
  match db with
  | Pack_db pack_db -> Pack.get ~db:pack_db ~key
  | Git_db git_db -> Git.get ~db:git_db ~key

let get_tree ~db ~(key : string list) ~offset ~length =
  match db with
  | Pack_db pack_db -> Pack.get_tree ~db:pack_db ~key ~offset ~length
  | Git_db git_db -> Git.get_tree ~db:git_db ~key ~offset ~length

let delete ~db ~(key : string list) ~message =
  match db with
  | Pack_db pack_db -> Pack.delete ~db:pack_db ~key ~message
  | Git_db git_db -> Git.delete ~db:git_db ~key ~message

let get_hash ~db ~(key : string list) =
  match db with
  | Pack_db pack_db -> Pack.get_hash ~db:pack_db ~key
  | Git_db git_db -> Git.get_hash ~db:git_db ~key

let exists ~db ~(key : string list) =
  match db with
  | Pack_db pack_db -> Pack.exists ~db:pack_db ~key
  | Git_db git_db -> Git.exists ~db:git_db ~key

let total ~db ~(key : string list) =
  match db with
  | Pack_db pack_db -> Pack.total ~db:pack_db ~key
  | Git_db git_db -> Git.total ~db:git_db ~key
