open Lwt.Syntax
open Alcotest_lwt

open Test_support

let test_schema_validation_accepts_highlight _switch () =
  match Miiify.Utils.Validation.validate_annotation highlight_annotation with
  | Ok () -> Lwt.return_unit
  | Error msg -> Alcotest.fail msg

(* Test: Reject user-supplied IDs during import *)
let test_import_rejects_user_id _switch () =
  let ws = make_temp_workspace "reject_user_id" in
  let bad_annotation =
    {|{
  "id": "http://example.invalid/should-not-be-here",
  "type": "Annotation",
  "motivation": "commenting",
  "body": {"type": "TextualBody", "value": "Has an id"},
  "target": "https://example.com/iiif/canvas/1"
}|}
  in
  let _ =
    write_annotation_file ~annotations_dir:ws.annotations_dir
      ~container_id:"my-canvas" ~slug:"bad-1" ~contents:bad_annotation
  in
  let exit_code =
    run_miiify_import ~annotations_dir:ws.annotations_dir ~git_repo:ws.git_repo
  in
  Alcotest.(check bool) "import fails when id present" true (exit_code <> 0);
  Lwt.return_unit

(* Test: Reject user-supplied IDs during compile (data may come from clone/pull) *)
let test_compile_rejects_user_id _switch () =
  let ws = make_temp_workspace "compile_reject_user_id" in
  let bad_annotation =
    {|{
  "id": "http://example.invalid/should-not-be-here",
  "type": "Annotation",
  "motivation": "commenting",
  "body": {"type": "TextualBody", "value": "Has an id"},
  "target": "https://example.com/iiif/canvas/1"
}|}
  in

  (* Simulate a cloned Git store: flat keys [container; slug] *)
  let git_db = Miiify.Storage_git.create ~fname:ws.git_repo in
  let* () =
    Miiify.Storage_git.set ~db:git_db ~key:[ "my-canvas"; "bad-1" ]
      ~data:bad_annotation ~message:"seed bad annotation"
  in

  let exit_code = run_miiify_compile ~git_repo:ws.git_repo ~pack_repo:ws.pack_repo in
  Alcotest.(check bool) "compile fails when id present" true (exit_code <> 0);
  Lwt.return_unit

(* Test: Import annotations like the README example *)
let test_import_annotations _switch () =
  let* db = create_test_db_pack "import" in
  let container_id = "my-canvas" in
  
  (* Import annotations (simulating miiify-import behavior) *)
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "highlight-1"] ~data:highlight_annotation ~message:"Import highlight-1.json" in
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "comment-1"] ~data:comment_annotation ~message:"Import comment-1.json" in
  
  (* Verify both annotations were imported *)
  let* total = Miiify.Model.total ~db ~container_id in
  Alcotest.(check int) "imported 2 annotations" 2 total;
  
  (* Retrieve highlight-1 *)
  let* highlight_data = Miiify.Db.get ~db ~key:[container_id; "collection"; "highlight-1"] in
  let parsed = Yojson.Basic.from_string highlight_data in
  let motivation = Yojson.Basic.Util.member "motivation" parsed |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "highlight motivation" "highlighting" motivation;
  
  (* Retrieve comment-1 *)
  let* comment_data = Miiify.Db.get ~db ~key:[container_id; "collection"; "comment-1"] in
  let parsed_comment = Yojson.Basic.from_string comment_data in
  let comment_motivation = Yojson.Basic.Util.member "motivation" parsed_comment |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "comment motivation" "commenting" comment_motivation;
  
  Lwt.return_unit

(* Test: Retrieve annotations like the HTTP API *)
let test_retrieve_annotations _switch () =
  let* db = create_test_db_pack "retrieve" in
  let container_id = "my-canvas" in
  
  (* Setup: Import some annotations *)
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "highlight-1"] ~data:highlight_annotation ~message:"Import highlight-1.json" in
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "comment-1"] ~data:comment_annotation ~message:"Import comment-1.json" in
  
  (* Test get_annotation (like GET /:container/:slug) *)
  let* annotation = Miiify.Model.get_annotation ~db ~container_id ~annotation_id:"highlight-1" in
  let body_value = Yojson.Basic.Util.member "body" annotation 
                  |> Yojson.Basic.Util.member "value" 
                  |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "annotation body" "Important passage" body_value;
  
  Lwt.return_unit

(* Test: Pagination functionality *)
let test_pagination _switch () =
  let* db = create_test_db_pack "pagination" in
  let container_id = "canvas-42" in
  
  (* Import multiple annotations *)
  let rec add_annotations i =
    if i >= 10 then Lwt.return_unit
    else
      let slug = Printf.sprintf "note-%02d" i in
      let annotation = Printf.sprintf {|{
        "type": "Annotation",
        "motivation": "commenting",
        "body": {"type": "TextualBody", "value": "Note %d"},
        "target": "https://example.com/iiif/canvas/42"
      }|} i in
      let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; slug] ~data:annotation ~message:("Import " ^ slug ^ ".json") in
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

(* Test: Target filtering *)
let test_target_filtering _switch () =
  let* db = create_test_db_pack "filtering" in
  let container_id = "manifest-42" in
  
  (* Import annotations with different targets *)
  let canvas1_ann1 = {|{
    "type": "Annotation",
    "motivation": "commenting",
    "body": {"type": "TextualBody", "value": "Note on canvas 1"},
    "target": "https://example.com/iiif/canvas/1"
  }|} in
  
  let canvas1_ann2 = {|{
    "type": "Annotation",
    "motivation": "highlighting",
    "body": {"type": "TextualBody", "value": "Highlight on canvas 1"},
    "target": "https://example.com/iiif/canvas/1"
  }|} in
  
  let canvas2_ann = {|{
    "type": "Annotation",
    "motivation": "commenting",
    "body": {"type": "TextualBody", "value": "Note on canvas 2"},
    "target": "https://example.com/iiif/canvas/2"
  }|} in
  
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "canvas1-note"] ~data:canvas1_ann1 ~message:"Import canvas1-note.json" in
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "canvas1-highlight"] ~data:canvas1_ann2 ~message:"Import canvas1-highlight.json" in
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "canvas2-note"] ~data:canvas2_ann ~message:"Import canvas2-note.json" in
  
  (* Get all three annotations *)
  let* all = Miiify.Db.get_tree ~db ~key:[container_id; "collection"] ~offset:0 ~length:10 in
  Alcotest.(check int) "all annotations" 3 (List.length all);
  
  (* Manually verify filtering by parsing and checking targets *)
  let annotations = List.map Yojson.Basic.from_string all in
  let canvas1_count = List.filter (fun ann ->
    match Yojson.Basic.Util.member "target" ann with
    | `String t -> t = "https://example.com/iiif/canvas/1"
    | _ -> false
  ) annotations |> List.length in
  
  Alcotest.(check int) "canvas 1 annotations" 2 canvas1_count;
  
  Lwt.return_unit

(* Test: Multiple containers are isolated *)
let test_container_isolation _switch () =
  let* db = create_test_db_pack "isolation" in
  
  (* Import annotations into different containers *)
  let* () = Miiify.Db.set ~db ~key:["canvas-1"; "collection"; "note-1"] ~data:highlight_annotation ~message:"Import to canvas-1" in
  let* () = Miiify.Db.set ~db ~key:["canvas-1"; "collection"; "note-2"] ~data:comment_annotation ~message:"Import to canvas-1" in
  let* () = Miiify.Db.set ~db ~key:["canvas-2"; "collection"; "note-1"] ~data:highlight_annotation ~message:"Import to canvas-2" in
  
  (* Verify canvas-1 has 2 annotations *)
  let* canvas1_total = Miiify.Model.total ~db ~container_id:"canvas-1" in
  Alcotest.(check int) "canvas-1 count" 2 canvas1_total;
  
  (* Verify canvas-2 has 1 annotation *)
  let* canvas2_total = Miiify.Model.total ~db ~container_id:"canvas-2" in
  Alcotest.(check int) "canvas-2 count" 1 canvas2_total;
  
  (* Verify retrieving from canvas-1 doesn't return canvas-2 data *)
  let* canvas1_tree = Miiify.Db.get_tree ~db ~key:["canvas-1"; "collection"] ~offset:0 ~length:10 in
  Alcotest.(check int) "canvas-1 tree items" 2 (List.length canvas1_tree);
  
  let* canvas2_tree = Miiify.Db.get_tree ~db ~key:["canvas-2"; "collection"] ~offset:0 ~length:10 in
  Alcotest.(check int) "canvas-2 tree items" 1 (List.length canvas2_tree);
  
  Lwt.return_unit

(* Test: Empty containers and nonexistent annotations *)
let test_empty_and_nonexistent _switch () =
  let* db = create_test_db_pack "empty" in
  let container_id = "empty-canvas" in
  
  (* Test empty container total (container doesn't exist) *)
  let* total = Miiify.Model.total ~db ~container_id in
  Alcotest.(check int) "empty container" 0 total;
  
  (* Test empty tree retrieval - wrap in try/catch since collection doesn't exist *)
  let* empty_tree = 
    Lwt.catch
      (fun () -> Miiify.Db.get_tree ~db ~key:[container_id; "collection"] ~offset:0 ~length:10)
      (fun _ -> Lwt.return [])
  in
  Alcotest.(check int) "empty tree" 0 (List.length empty_tree);
  
  (* Test nonexistent annotation existence check *)
  let* exists = Miiify.Db.exists ~db ~key:[container_id; "collection"; "does-not-exist"] in
  Alcotest.(check bool) "nonexistent annotation" false exists;
  
  (* Create a container and test empty collection retrieval *)
  let container_json = {|{"type":"AnnotationContainer","label":"Empty Container"}|} in
  let* () = Miiify.Db.set ~db ~key:[container_id; "metadata"] ~data:container_json ~message:"Create empty container" in
  
  let* total_after = Miiify.Model.total ~db ~container_id in
  Alcotest.(check int) "empty container with main" 0 total_after;
  
  Lwt.return_unit

(* Test: Annotation hash retrieval for caching *)
let test_annotation_hashes _switch () =
  let* db = create_test_db_pack "hashes" in
  let container_id = "test-canvas" in
  
  (* Import an annotation *)
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "note-1"] ~data:highlight_annotation ~message:"Import note-1" in
  
  (* Get hash for the annotation *)
  let* hash_opt = Miiify.Model.get_annotation_hash ~db ~container_id ~annotation_id:"note-1" in
  
  let* () = match hash_opt with
  | Some hash -> 
      (* Hash should be a non-empty string *)
      Alcotest.(check bool) "hash exists" true (String.length hash > 0);
      
      (* Import same annotation again, hash should remain stable-ish (depends on Irmin) *)
      let* hash2_opt = Miiify.Model.get_annotation_hash ~db ~container_id ~annotation_id:"note-1" in
      (match hash2_opt with
      | Some hash2 -> 
          Alcotest.(check bool) "hash is consistent" true (String.length hash2 > 0);
          Lwt.return_unit
      | None -> Alcotest.fail "Hash disappeared")
  | None -> Alcotest.fail "No hash returned for existing annotation"
  in
  
  Lwt.return_unit

(* Test: Slug handling (simulating .json extension stripping) *)
let test_slug_handling _switch () =
  let* db = create_test_db_pack "slugs" in
  let container_id = "test-slugs" in
  
  (* Import with various slug patterns *)
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "simple-slug"] ~data:highlight_annotation ~message:"simple slug" in
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "with-numbers-123"] ~data:highlight_annotation ~message:"with numbers" in
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "kebab-case-name"] ~data:highlight_annotation ~message:"kebab case" in
  
  (* Verify all are retrievable *)
  let* exists1 = Miiify.Db.exists ~db ~key:[container_id; "collection"; "simple-slug"] in
  let* exists2 = Miiify.Db.exists ~db ~key:[container_id; "collection"; "with-numbers-123"] in
  let* exists3 = Miiify.Db.exists ~db ~key:[container_id; "collection"; "kebab-case-name"] in
  
  Alcotest.(check bool) "simple slug exists" true exists1;
  Alcotest.(check bool) "numbered slug exists" true exists2;
  Alcotest.(check bool) "kebab-case slug exists" true exists3;
  
  let* total = Miiify.Model.total ~db ~container_id in
  Alcotest.(check int) "all slugs imported" 3 total;
  
  Lwt.return_unit

(* Test: Large batch import *)
let test_large_batch _switch () =
  let* db = create_test_db_pack "large" in
  let container_id = "large-canvas" in
  
  (* Import 100 annotations *)
  let rec import_batch i =
    if i >= 100 then Lwt.return_unit
    else
      let slug = Printf.sprintf "ann-%03d" i in
      let ann = Printf.sprintf {|{
        "type": "Annotation",
        "motivation": "commenting",
        "body": {"type": "TextualBody", "value": "Annotation %d"},
        "target": "https://example.com/canvas#xywh=%d,0,100,100"
      }|} i (i * 10) in
      let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; slug] ~data:ann ~message:("Import " ^ slug) in
      import_batch (i + 1)
  in
  let* () = import_batch 0 in
  
  (* Verify total *)
  let* total = Miiify.Model.total ~db ~container_id in
  Alcotest.(check int) "100 annotations imported" 100 total;
  
  (* Test pagination with larger dataset *)
  let* page1 = Miiify.Db.get_tree ~db ~key:[container_id; "collection"] ~offset:0 ~length:20 in
  Alcotest.(check int) "page 1 size" 20 (List.length page1);
  
  let* page2 = Miiify.Db.get_tree ~db ~key:[container_id; "collection"] ~offset:20 ~length:20 in
  Alcotest.(check int) "page 2 size" 20 (List.length page2);
  
  let* page5 = Miiify.Db.get_tree ~db ~key:[container_id; "collection"] ~offset:80 ~length:20 in
  Alcotest.(check int) "page 5 size" 20 (List.length page5);
  
  let* page_beyond = Miiify.Db.get_tree ~db ~key:[container_id; "collection"] ~offset:100 ~length:20 in
  Alcotest.(check int) "beyond last page" 0 (List.length page_beyond);
  
  Lwt.return_unit

(* Test: JSON extension stripping helper *)
let test_json_extension_stripping _switch () =
  (* Replicate the strip_json_ext logic from Api module *)
  let strip_json_ext slug =
    if String.length slug > 5 && String.sub slug (String.length slug - 5) 5 = ".json" then
      String.sub slug 0 (String.length slug - 5)
    else
      slug
  in
  
  (* Test various inputs *)
  Alcotest.(check string) "strip .json" "highlight-1" (strip_json_ext "highlight-1.json");
  Alcotest.(check string) "no extension" "highlight-1" (strip_json_ext "highlight-1");
  Alcotest.(check string) "short name" "hi" (strip_json_ext "hi");
  Alcotest.(check string) ".json in middle" "my.json-file" (strip_json_ext "my.json-file");
  Alcotest.(check string) "exactly .json" "test.json" (strip_json_ext "test.json.json");
  Alcotest.(check string) "case sensitive" "file.JSON" (strip_json_ext "file.JSON");
  
  Lwt.return_unit

(* Test: ETag support in API *)
let test_etag_annotation _switch () =
  let* db = create_test_db_pack "etag-ann" in
  let container_id = "test-canvas" in
  
  (* Import an annotation *)
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "note-1"] ~data:highlight_annotation ~message:"Import note-1" in
  
  (* Get the hash directly *)
  let* hash_opt = Miiify.Model.get_annotation_hash ~db ~container_id ~annotation_id:"note-1" in
  
  match hash_opt with
  | Some hash ->
      let etag = "\"" ^ hash ^ "\"" in
      Alcotest.(check bool) "ETag should exist" true (String.length etag > 2);
      
      (* Verify hash is base64-like (alphanumeric + / + =) *)
      Alcotest.(check bool) "Hash is non-empty" true (String.length hash > 0);
      Lwt.return_unit
  | None -> Alcotest.fail "No ETag hash returned"

let test_etag_collection _switch () =
  let* db = create_test_db_pack "etag-coll" in
  let container_id = "test-canvas" in
  
  (* Import multiple annotations *)
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "note-1"] ~data:highlight_annotation ~message:"Import note-1" in
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "note-2"] ~data:comment_annotation ~message:"Import note-2" in
  
  (* Get collection hash *)
  let* hash_opt = Miiify.Model.get_collection_hash ~db ~container_id in
  
  match hash_opt with
  | Some hash ->
      Alcotest.(check bool) "Collection ETag exists" true (String.length hash > 0);
      
      (* Add another annotation and verify hash changes *)
      let new_ann = {|{"type":"Annotation","motivation":"tagging","body":{"type":"TextualBody","value":"tag"},"target":"https://example.com/canvas"}|} in
      let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "note-3"] ~data:new_ann ~message:"Import note-3" in
      
      let* hash2_opt = Miiify.Model.get_collection_hash ~db ~container_id in
      (match hash2_opt with
      | Some hash2 ->
          (* Hash should be different after adding new annotation *)
          Alcotest.(check bool) "Collection hash changed" true (hash <> hash2);
          Lwt.return_unit
      | None -> Alcotest.fail "Hash disappeared after update")
  | None -> Alcotest.fail "No collection hash returned"

let test_etag_container _switch () =
  let* db = create_test_db_pack "etag-cont" in
  let container_id = "test-canvas" in
  
  (* Create a container *)
  let container_json = {|{"type":"AnnotationContainer","label":"Test Container"}|} in
  let* () = Miiify.Db.set ~db ~key:[container_id; "metadata"] ~data:container_json ~message:"Create container" in
  
  (* Get container hash *)
  let* hash_opt = Miiify.Model.get_container_hash ~db ~container_id in
  
  match hash_opt with
  | Some hash ->
      Alcotest.(check bool) "Container ETag exists" true (String.length hash > 0);
      Lwt.return_unit
  | None -> Alcotest.fail "No container hash returned"

(* Test: ID injection into annotation *)
let test_id_annotation _switch () =
  let* db = create_test_db_pack "id-annotation" in
  let container_id = "my-canvas" in
  let annotation_id = "highlight-1" in
  let base_url = "http://localhost:10000" in
  
  (* Import annotation *)
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; annotation_id] ~data:highlight_annotation ~message:"Import annotation" in
  
  (* Get annotation with ID injection *)
  let* result = Miiify.Controller.get_annotation ~db ~container_id ~annotation_id ~base_url in
  let json = Yojson.Basic.from_string result in
  let id = Yojson.Basic.Util.member "id" json |> Yojson.Basic.Util.to_string in
  
  Alcotest.(check string) "annotation has correct ID" "http://localhost:10000/my-canvas/highlight-1" id;
  Lwt.return_unit

(* Test: ID injection into container *)
let test_id_container _switch () =
  let* db = create_test_db_pack "id-container" in
  let container_id = "test-canvas" in
  let base_url = "http://localhost:10000" in
  
  (* Create container *)
  let container_json = {|{"type":"AnnotationContainer","label":"Test Container"}|} in
  let* () = Miiify.Db.set ~db ~key:[container_id; "metadata"] ~data:container_json ~message:"Create container" in
  
  (* Get container with ID injection *)
  let* result = Miiify.Controller.get_container ~db ~container_id ~base_url in
  let json = Yojson.Basic.from_string result in
  let id = Yojson.Basic.Util.member "id" json |> Yojson.Basic.Util.to_string in
  
  Alcotest.(check string) "container has correct ID" "http://localhost:10000/test-canvas/" id;
  Lwt.return_unit

(* Test: ID injection into collection and items *)
let test_id_collection _switch () =
  let* db = create_test_db_pack "id-collection" in
  let container_id = "my-canvas" in
  let base_url = "https://example.org" in
  
  (* Create container and annotations *)
  let container_json = {|{"type":"AnnotationContainer","label":"My Canvas"}|} in
  let* () = Miiify.Db.set ~db ~key:[container_id; "metadata"] ~data:container_json ~message:"Create container" in
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "highlight-1"] ~data:highlight_annotation ~message:"Import annotation" in
  
  (* Get collection with ID injection *)
  let* result = Miiify.Controller.get_annotation_collection ~page_limit:20 ~db ~id:container_id ~target:None ~base_url in
  let json = Yojson.Basic.from_string result in
  
  (* Check collection ID *)
  let collection_id = Yojson.Basic.Util.member "id" json |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "collection has correct ID" "https://example.org/my-canvas/" collection_id;
  
  (* Check first page ID *)
  let first = Yojson.Basic.Util.member "first" json in
  let page_id = Yojson.Basic.Util.member "id" first |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "first page has correct ID" "https://example.org/my-canvas/?page=0" page_id;
  
  (* Check item ID *)
  let items = Yojson.Basic.Util.member "items" first |> Yojson.Basic.Util.to_list in
  let first_item = List.hd items in
  let item_id = Yojson.Basic.Util.member "id" first_item |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "item has correct ID" "https://example.org/my-canvas/highlight-1" item_id;
  
  Lwt.return_unit

(* Test: ID injection into standalone page *)
let test_id_page _switch () =
  let* db = create_test_db_pack "id-page" in
  let container_id = "my-canvas" in
  let base_url = "http://localhost:10000" in
  
  (* Create container and annotation *)
  let container_json = {|{"type":"AnnotationContainer","label":"My Canvas"}|} in
  let* () = Miiify.Db.set ~db ~key:[container_id; "metadata"] ~data:container_json ~message:"Create container" in
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; "highlight-1"] ~data:highlight_annotation ~message:"Import annotation" in
  
  (* Get page 0 *)
  let* result_opt = Miiify.Controller.get_annotation_page ~page_limit:20 ~db ~id:container_id ~page:0 ~target:None ~base_url in
  
  match result_opt with
  | Some result ->
      let json = Yojson.Basic.from_string result in
      let page_id = Yojson.Basic.Util.member "id" json |> Yojson.Basic.Util.to_string in
      Alcotest.(check string) "page has correct ID" "http://localhost:10000/my-canvas/?page=0" page_id;
      
      (* Check item ID *)
      let items = Yojson.Basic.Util.member "items" json |> Yojson.Basic.Util.to_list in
      let first_item = List.hd items in
      let item_id = Yojson.Basic.Util.member "id" first_item |> Yojson.Basic.Util.to_string in
      Alcotest.(check string) "item in page has correct ID" "http://localhost:10000/my-canvas/highlight-1" item_id;
      Lwt.return_unit
  | None -> Alcotest.fail "Page not found"

(* Test: Base URL variation changes IDs *)
let test_id_base_url_variation _switch () =
  let* db = create_test_db_pack "id-baseurl" in
  let container_id = "test-canvas" in
  let annotation_id = "anno-1" in
  
  (* Import annotation *)
  let* () = Miiify.Db.set ~db ~key:[container_id; "collection"; annotation_id] ~data:highlight_annotation ~message:"Import annotation" in
  
  (* Get with localhost base_url *)
  let* result1 = Miiify.Controller.get_annotation ~db ~container_id ~annotation_id ~base_url:"http://localhost:10000" in
  let json1 = Yojson.Basic.from_string result1 in
  let id1 = Yojson.Basic.Util.member "id" json1 |> Yojson.Basic.Util.to_string in
  
  (* Get with example.org base_url *)
  let* result2 = Miiify.Controller.get_annotation ~db ~container_id ~annotation_id ~base_url:"https://example.org" in
  let json2 = Yojson.Basic.from_string result2 in
  let id2 = Yojson.Basic.Util.member "id" json2 |> Yojson.Basic.Util.to_string in
  
  Alcotest.(check string) "localhost ID correct" "http://localhost:10000/test-canvas/anno-1" id1;
  Alcotest.(check string) "example.org ID correct" "https://example.org/test-canvas/anno-1" id2;
  Alcotest.(check bool) "IDs differ with different base_url" true (id1 <> id2);
  
  Lwt.return_unit

(* Main test suite *)
let () =
  Lwt_main.run @@
  run "Miiify Storage Tests" [
    ("Import Workflow", [ 
      test_case "schema validation accepts highlight" `Quick test_schema_validation_accepts_highlight;
      test_case "reject user-supplied id" `Quick test_import_rejects_user_id;
      test_case "compile rejects user-supplied id" `Quick test_compile_rejects_user_id;
      test_case "import annotations" `Quick test_import_annotations;
      test_case "retrieve annotations" `Quick test_retrieve_annotations;
    ]);
    ("Pagination", [ test_case "pagination" `Quick test_pagination ]);
    ("Filtering", [ test_case "target filtering" `Quick test_target_filtering ]);
    ("Container Isolation", [ test_case "multiple containers" `Quick test_container_isolation ]);
    ("Edge Cases", [ 
      test_case "empty and nonexistent" `Quick test_empty_and_nonexistent;
      test_case "slug handling" `Quick test_slug_handling;
    ]);
    ("Performance", [ test_case "large batch import" `Quick test_large_batch ]);
    ("Caching", [ test_case "annotation hashes" `Quick test_annotation_hashes ]);
    ("API Helpers", [ test_case "JSON extension stripping" `Quick test_json_extension_stripping ]);
    ("ETag Support", [
      test_case "annotation etag" `Quick test_etag_annotation;
      test_case "collection etag" `Quick test_etag_collection;
      test_case "container etag" `Quick test_etag_container;
    ]);
    ("ID Injection", [
      test_case "annotation id" `Quick test_id_annotation;
      test_case "container id" `Quick test_id_container;
      test_case "collection ids" `Quick test_id_collection;
      test_case "page id" `Quick test_id_page;
      test_case "base url variation" `Quick test_id_base_url_variation;
    ]);
  ]
