open Lwt.Syntax
open Alcotest_lwt

open Test_support

module type BACKEND = sig
  type t

  val create : fname:string -> t
  val set : db:t -> key:string list -> data:string -> message:string -> unit Lwt.t
  val get : db:t -> key:string list -> string Lwt.t
  val get_tree :
    db:t -> key:string list -> offset:int -> length:int -> string list Lwt.t

  val get_tree_with_keys :
    db:t ->
    key:string list ->
    offset:int ->
    length:int ->
    (string * string) list Lwt.t

  val delete : db:t -> key:string list -> message:string -> unit Lwt.t
  val exists : db:t -> key:string list -> bool Lwt.t
  val total : db:t -> key:string list -> int Lwt.t
  val get_hash : db:t -> key:string list -> string option Lwt.t
end

let ensure_dir path =
  if Sys.file_exists path then () else Unix.mkdir path 0o755

let mk_annotation value =
  Printf.sprintf
    {|{"type":"Annotation","motivation":"commenting","body":{"type":"TextualBody","value":"%s"},"target":"https://example.com/iiif/canvas/1"}|}
    value

let contract_tests
    (type db)
    ~(name : string)
    (module B : BACKEND with type t = db)
    ~(repo_path : string) =
  let test_set_get_exists_total_delete _switch () =
    ensure_dir repo_path;
    let db = B.create ~fname:repo_path in
    let container_id = "c" in
    let coll_key = [ container_id; "collection" ] in
    let key_a = coll_key @ [ "a" ] in
    let key_b = coll_key @ [ "b" ] in
    let data_a = mk_annotation "A" in
    let data_b = mk_annotation "B" in

    let* () = B.set ~db ~key:key_a ~data:data_a ~message:"seed a" in
    let* () = B.set ~db ~key:key_b ~data:data_b ~message:"seed b" in

    let* exists_a = B.exists ~db ~key:key_a in
    Alcotest.(check bool) "exists a" true exists_a;

    let* got_a = B.get ~db ~key:key_a in
    Alcotest.(check string) "get a" data_a got_a;

    let* total = B.total ~db ~key:coll_key in
    Alcotest.(check int) "total=2" 2 total;

    let* () = B.delete ~db ~key:key_a ~message:"delete a" in
    let* exists_a_after = B.exists ~db ~key:key_a in
    Alcotest.(check bool) "a deleted" false exists_a_after;

    let* total_after = B.total ~db ~key:coll_key in
    Alcotest.(check int) "total=1 after delete" 1 total_after;

    Lwt.return_unit
  in

  let test_tree_ordering_and_paging _switch () =
    ensure_dir repo_path;
    let db = B.create ~fname:repo_path in
    let container_id = "sort" in
    let coll_key = [ container_id; "collection" ] in

    let* () =
      B.set ~db ~key:(coll_key @ [ "b" ]) ~data:(mk_annotation "B")
        ~message:"seed b"
    in
    let* () =
      B.set ~db ~key:(coll_key @ [ "a" ]) ~data:(mk_annotation "A")
        ~message:"seed a"
    in
    let* () =
      B.set ~db ~key:(coll_key @ [ "c" ]) ~data:(mk_annotation "C")
        ~message:"seed c"
    in

    let* values = B.get_tree ~db ~key:coll_key ~offset:0 ~length:10 in
    let body_values =
      List.map
        (fun raw ->
          let json = Yojson.Basic.from_string raw in
          Yojson.Basic.Util.member "body" json
          |> Yojson.Basic.Util.member "value" |> Yojson.Basic.Util.to_string)
        values
    in
    Alcotest.(check (list string)) "get_tree is sorted" [ "A"; "B"; "C" ]
      body_values;

    let* with_keys =
      B.get_tree_with_keys ~db ~key:coll_key ~offset:0 ~length:10
    in
    Alcotest.(check (list string)) "keys sorted" [ "a"; "b"; "c" ]
      (List.map fst with_keys);

    let* page = B.get_tree_with_keys ~db ~key:coll_key ~offset:1 ~length:1 in
    Alcotest.(check (list string)) "paged keys" [ "b" ] (List.map fst page);

    Lwt.return_unit
  in

  let test_get_hash_for_blob _switch () =
    ensure_dir repo_path;
    let db = B.create ~fname:repo_path in
    let key = [ "h"; "collection"; "a" ] in
    let* () = B.set ~db ~key ~data:(mk_annotation "A") ~message:"seed" in
    let* hash_opt = B.get_hash ~db ~key in
    (match hash_opt with
    | Some hash -> Alcotest.(check bool) "hash non-empty" true (String.length hash > 0)
    | None -> Alcotest.fail "expected hash for stored blob");
    Lwt.return_unit
  in

  let test_missing_keys_contract _switch () =
    ensure_dir repo_path;
    let db = B.create ~fname:repo_path in
    let missing_tree = [ "missing"; "collection" ] in
    let missing_blob = missing_tree @ [ "a" ] in

    let* exists_tree = B.exists ~db ~key:missing_tree in
    Alcotest.(check bool) "missing tree does not exist" false exists_tree;

    let* total_tree = B.total ~db ~key:missing_tree in
    Alcotest.(check int) "missing tree total=0" 0 total_tree;

    let* hash_opt = B.get_hash ~db ~key:missing_blob in
    Alcotest.(check bool) "missing blob hash is None" true (hash_opt = None);

    let* tree_raises =
      Lwt.catch
        (fun () ->
          let* _ = B.get_tree ~db ~key:missing_tree ~offset:0 ~length:10 in
          Lwt.return false)
        (fun _ -> Lwt.return true)
    in
    Alcotest.(check bool) "get_tree missing raises" true tree_raises;

    let* with_keys_raises =
      Lwt.catch
        (fun () ->
          let* _ =
            B.get_tree_with_keys ~db ~key:missing_tree ~offset:0 ~length:10
          in
          Lwt.return false)
        (fun _ -> Lwt.return true)
    in
    Alcotest.(check bool) "get_tree_with_keys missing raises" true with_keys_raises;

    Lwt.return_unit
  in

  ( name,
    [
      test_case "set/get/exists/total/delete" `Quick test_set_get_exists_total_delete;
      test_case "tree ordering + paging" `Quick test_tree_ordering_and_paging;
      test_case "hash for blob" `Quick test_get_hash_for_blob;
      test_case "missing keys contract" `Quick test_missing_keys_contract;
    ] )

let () =
  let ws_pack = make_temp_workspace "db_contract_pack" in
  let ws_git = make_temp_workspace "db_contract_git" in
  Lwt_main.run @@
  run "Miiify DB Contract Tests"
    [
      contract_tests ~name:"Pack" (module Miiify.Storage_pack)
        ~repo_path:ws_pack.pack_repo;
      contract_tests ~name:"Git" (module Miiify.Storage_git) ~repo_path:ws_git.git_repo;
    ]
