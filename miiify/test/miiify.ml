open Lwt.Syntax
open Alcotest_lwt

(* Helper to create a fresh database *)
let create_test_db test_name =
  let repository_name = Printf.sprintf "test_pack_%s_%f" test_name (Unix.time ()) in
  Miiify.Model.create ~repository_name

(* Sample JSON data *)
let container_json = {|{
  "type": "AnnotationCollection",
  "@context": "http://www.w3.org/ns/anno.jsonld",
  "id": "http://localhost:10000/test-container/",
  "label": "Test Container"
}|}

let annotation_json = {|{
  "type": "Annotation",
  "@context": "http://www.w3.org/ns/anno.jsonld",
  "body": {
    "type": "TextualBody",
    "value": "Test annotation"
  },
  "target": "https://example.com/target"
}|}

(* Test: Create and retrieve a container *)
let test_container_crud _switch () =
  let* db = create_test_db "container_crud" in
  let container_id = "test-container" in
  
  (* CREATE: Add a container *)
  let* () = Miiify.Db.set ~db ~key:[container_id; "main"] ~data:container_json ~message:"create test container" in
  
  (* READ: Retrieve the container *)
  let* retrieved_data = Miiify.Db.get ~db ~key:[container_id; "main"] in
  let parsed = Yojson.Basic.from_string retrieved_data in
  let container_type = Yojson.Basic.Util.member "type" parsed |> Yojson.Basic.Util.to_string in
  
  Alcotest.(check string) "container type" "AnnotationCollection" container_type;
  
  (* CHECK: Container should exist *)
  let* exists = Miiify.Db.exists ~db ~key:[container_id; "main"] in
  Alcotest.(check bool) "container exists" true exists;
  
  (* DELETE: Remove the container *)
  let* () = Miiify.Db.delete ~db ~key:[container_id; "main"] ~message:"delete test container" in
  
  (* VERIFY: Container should no longer exist *)
  let* exists_after = Miiify.Db.exists ~db ~key:[container_id; "main"] in
  Alcotest.(check bool) "container deleted" false exists_after;
  
  Lwt.return_unit

(* Test: Create, count, and manage annotations *)
let test_annotation_crud _switch () =
  let* db = create_test_db "annotation_crud" in
  let container_id = "test-container" in
  
  (* Setup: Create container first *)
  let* () = Miiify.Db.set ~db ~key:[container_id; "main"] ~data:container_json ~message:"create container" in
  
  (* Initial state: No annotations should exist *)
  let* initial_total = Miiify.Model.total ~db ~container_id in
  Alcotest.(check int) "initial count" 0 initial_total;
  
  (* CREATE: Add some annotations *)
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "ann1"] ~data:annotation_json ~message:"add annotation 1" in
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "ann2"] ~data:annotation_json ~message:"add annotation 2" in
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "ann3"] ~data:annotation_json ~message:"add annotation 3" in
  
  (* COUNT: Check total annotations *)
  let* total_after_add = Miiify.Model.total ~db ~container_id in
  Alcotest.(check int) "after adding 3" 3 total_after_add;
  
  (* READ: Retrieve an annotation *)
  let* annotation_data = Miiify.Db.get ~db ~key:[container_id; "collection"; "ann2"] in
  let parsed = Yojson.Basic.from_string annotation_data in
  let annotation_type = Yojson.Basic.Util.member "type" parsed |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "annotation type" "Annotation" annotation_type;
  
  (* CHECK: Annotation should exist *)
  let* exists = Miiify.Db.exists ~db ~key:[container_id; "collection"; "ann2"] in
  Alcotest.(check bool) "annotation exists" true exists;
  
  (* UPDATE: Modify an annotation *)
  let updated_json = {|{
    "type": "Annotation",
    "@context": "http://www.w3.org/ns/anno.jsonld",
    "body": {
      "type": "TextualBody",
      "value": "Updated annotation"
    },
    "target": "https://example.com/updated-target"
  }|} in
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "ann2"] ~data:updated_json ~message:"update annotation 2" in
  
  (* VERIFY: Updated content *)
  let* updated_data = Miiify.Db.get ~db ~key:[container_id; "collection"; "ann2"] in
  let updated_parsed = Yojson.Basic.from_string updated_data in
  let updated_value = Yojson.Basic.Util.member "body" updated_parsed 
                     |> Yojson.Basic.Util.member "value" 
                     |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "updated value" "Updated annotation" updated_value;
  
  (* COUNT: Should still be 3 after update *)
  let* total_after_update = Miiify.Model.total ~db ~container_id in
  Alcotest.(check int) "after update still 3" 3 total_after_update;
  
  (* DELETE: Remove one annotation *)
  let* () = Miiify.Db.delete ~db ~key:[container_id; "collection"; "ann2"] ~message:"delete annotation 2" in
  
  (* COUNT: Should now be 2 *)
  let* total_after_delete = Miiify.Model.total ~db ~container_id in
  Alcotest.(check int) "after delete" 2 total_after_delete;
  
  (* VERIFY: Deleted annotation should not exist *)
  let* deleted_exists = Miiify.Db.exists ~db ~key:[container_id; "collection"; "ann2"] in
  Alcotest.(check bool) "deleted annotation gone" false deleted_exists;
  
  (* VERIFY: Other annotations still exist *)
  let* ann1_exists = Miiify.Db.exists ~db ~key:[container_id; "collection"; "ann1"] in
  let* ann3_exists = Miiify.Db.exists ~db ~key:[container_id; "collection"; "ann3"] in
  Alcotest.(check bool) "ann1 still exists" true ann1_exists;
  Alcotest.(check bool) "ann3 still exists" true ann3_exists;
  
  Lwt.return_unit

(* Test: Pagination functionality *)
let test_pagination _switch () =
  let* db = create_test_db "pagination" in
  let container_id = "test-container" in
  
  (* Setup: Create container *)
  let* () = Miiify.Db.set ~db ~key:[container_id; "main"] ~data:container_json ~message:"create container" in
  
  (* Add 10 annotations *)
  let rec add_annotations i =
    if i >= 10 then Lwt.return_unit
    else
      let annotation_id = Printf.sprintf "ann-%02d" i in
      let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; annotation_id] ~data:annotation_json ~message:("add " ^ annotation_id) in
      add_annotations (i + 1)
  in
  let* () = add_annotations 0 in
  
  (* Verify total count *)
  let* total = Miiify.Model.total ~db ~container_id in
  Alcotest.(check int) "total 10 annotations" 10 total;
  
  (* Test pagination: First 5 items *)
  let* first_page = Miiify.Db.get_tree ~db ~key:[container_id; "collection"] ~offset:0 ~length:5 in
  Alcotest.(check int) "first page size" 5 (List.length first_page);
  
  (* Test pagination: Next 5 items *)
  let* second_page = Miiify.Db.get_tree ~db ~key:[container_id; "collection"] ~offset:5 ~length:5 in
  Alcotest.(check int) "second page size" 5 (List.length second_page);
  
  (* Test pagination: Beyond available items *)
  let* empty_page = Miiify.Db.get_tree ~db ~key:[container_id; "collection"] ~offset:10 ~length:5 in
  Alcotest.(check int) "empty page" 0 (List.length empty_page);
  
  Lwt.return_unit

(* Main test suite *)
let () =
  Lwt_main.run @@
  run "Miiify Storage Tests" [
    ("Container CRUD", [ test_case "create and retrieve" `Quick test_container_crud ]);
    ("Annotation CRUD", [ test_case "create and count" `Quick test_annotation_crud ]);
    ("Pagination", [ test_case "pagination" `Quick test_pagination ]);
  ]
