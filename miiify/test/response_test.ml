open Lwt.Syntax
open Alcotest_lwt

open Test_support

(* Test: JSON extension stripping helper *)
let test_json_extension_stripping _switch () =
  (* Replicate the strip_json_ext logic from Api module *)
  let strip_json_ext slug =
    if
      String.length slug > 5
      && String.sub slug (String.length slug - 5) 5 = ".json"
    then
      String.sub slug 0 (String.length slug - 5)
    else
      slug
  in

  (* Test various inputs *)
  Alcotest.(check string) "strip .json" "highlight-1"
    (strip_json_ext "highlight-1.json");
  Alcotest.(check string) "no extension" "highlight-1"
    (strip_json_ext "highlight-1");
  Alcotest.(check string) "short name" "hi" (strip_json_ext "hi");
  Alcotest.(check string) ".json in middle" "my.json-file"
    (strip_json_ext "my.json-file");
  Alcotest.(check string) "exactly .json" "test.json"
    (strip_json_ext "test.json.json");
  Alcotest.(check string) "case sensitive" "file.JSON"
    (strip_json_ext "file.JSON");

  Lwt.return_unit

(* Test: ID injection into annotation *)
let test_id_annotation _switch () =
  let* db = create_test_db_pack "id-annotation" in
  let container_id = "my-canvas" in
  let annotation_id = "highlight-1" in
  let base_url = "http://localhost:10000" in

  (* Import annotation *)
  let* () =
    Miiify.Db.set ~db ~key:[ container_id; "collection"; annotation_id ]
      ~data:highlight_annotation ~message:"Import annotation"
  in

  (* Get annotation with ID injection *)
  let* result =
    Miiify.Controller.get_annotation ~db ~container_id ~annotation_id ~base_url
  in
  let json = Yojson.Basic.from_string result in
  let id = Yojson.Basic.Util.member "id" json |> Yojson.Basic.Util.to_string in

  Alcotest.(check string) "annotation has correct ID"
    "http://localhost:10000/my-canvas/highlight-1" id;
  Lwt.return_unit

(* Test: ID injection into container *)
let test_id_container _switch () =
  let* db = create_test_db_pack "id-container" in
  let container_id = "test-canvas" in
  let base_url = "http://localhost:10000" in

  (* Create container *)
  let container_json =
    {|{"type":"AnnotationCollection","label":"Test Container"}|}
  in
  let* () =
    Miiify.Db.set ~db ~key:[ container_id; "metadata" ] ~data:container_json
      ~message:"Create container"
  in

  (* Get container with ID injection *)
  let* result = Miiify.Controller.get_container ~db ~container_id ~base_url in
  let json = Yojson.Basic.from_string result in
  let id = Yojson.Basic.Util.member "id" json |> Yojson.Basic.Util.to_string in

  Alcotest.(check string) "container has correct ID"
    "http://localhost:10000/test-canvas/" id;
  Lwt.return_unit

(* Test: ID injection into collection and items *)
let test_id_collection _switch () =
  let* db = create_test_db_pack "id-collection" in
  let container_id = "my-canvas" in
  let base_url = "https://example.org" in

  (* Create container and annotations *)
  let container_json = {|{"type":"AnnotationCollection","label":"My Canvas"}|} in
  let* () =
    Miiify.Db.set ~db ~key:[ container_id; "metadata" ] ~data:container_json
      ~message:"Create container"
  in
  let* () =
    Miiify.Db.set ~db ~key:[ container_id; "collection"; "highlight-1" ]
      ~data:highlight_annotation ~message:"Import annotation"
  in

  (* Get collection with ID injection *)
  let* result =
    Miiify.Controller.get_annotation_collection ~page_limit:20 ~db ~id:container_id
      ~base_url
  in
  let json = Yojson.Basic.from_string result in

  (* Check collection ID *)
  let collection_id =
    Yojson.Basic.Util.member "id" json |> Yojson.Basic.Util.to_string
  in
  Alcotest.(check string) "collection has correct ID"
    "https://example.org/my-canvas/" collection_id;

  (* Check first page ID *)
  let first = Yojson.Basic.Util.member "first" json in
  let page_id = Yojson.Basic.Util.member "id" first |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "first page has correct ID"
    "https://example.org/my-canvas/?page=0" page_id;

  (* Check item ID *)
  let items = Yojson.Basic.Util.member "items" first |> Yojson.Basic.Util.to_list in
  let first_item = List.hd items in
  let item_id =
    Yojson.Basic.Util.member "id" first_item |> Yojson.Basic.Util.to_string
  in
  Alcotest.(check string) "item has correct ID"
    "https://example.org/my-canvas/highlight-1" item_id;

  Lwt.return_unit

(* Test: ID injection into standalone page *)
let test_id_page _switch () =
  let* db = create_test_db_pack "id-page" in
  let container_id = "my-canvas" in
  let base_url = "http://localhost:10000" in

  (* Create container and annotation *)
  let container_json = {|{"type":"AnnotationCollection","label":"My Canvas"}|} in
  let* () =
    Miiify.Db.set ~db ~key:[ container_id; "metadata" ] ~data:container_json
      ~message:"Create container"
  in
  let* () =
    Miiify.Db.set ~db ~key:[ container_id; "collection"; "highlight-1" ]
      ~data:highlight_annotation ~message:"Import annotation"
  in

  (* Get page 0 *)
  let* result_opt =
    Miiify.Controller.get_annotation_page ~page_limit:20 ~db ~id:container_id
      ~page:0 ~base_url
  in

  match result_opt with
  | Some result ->
      let json = Yojson.Basic.from_string result in
      let page_id =
        Yojson.Basic.Util.member "id" json |> Yojson.Basic.Util.to_string
      in
      Alcotest.(check string) "page has correct ID"
        "http://localhost:10000/my-canvas/?page=0" page_id;

      (* Check item ID *)
      let items = Yojson.Basic.Util.member "items" json |> Yojson.Basic.Util.to_list in
      let first_item = List.hd items in
      let item_id =
        Yojson.Basic.Util.member "id" first_item |> Yojson.Basic.Util.to_string
      in
      Alcotest.(check string) "item in page has correct ID"
        "http://localhost:10000/my-canvas/highlight-1" item_id;
      Lwt.return_unit
  | None -> Alcotest.fail "Page not found"

(* Test: Base URL variation changes IDs *)
let test_id_base_url_variation _switch () =
  let* db = create_test_db_pack "id-baseurl" in
  let container_id = "test-canvas" in
  let annotation_id = "anno-1" in

  (* Import annotation *)
  let* () =
    Miiify.Db.set ~db ~key:[ container_id; "collection"; annotation_id ]
      ~data:highlight_annotation ~message:"Import annotation"
  in

  (* Get with localhost base_url *)
  let* result1 =
    Miiify.Controller.get_annotation ~db ~container_id ~annotation_id
      ~base_url:"http://localhost:10000"
  in
  let json1 = Yojson.Basic.from_string result1 in
  let id1 = Yojson.Basic.Util.member "id" json1 |> Yojson.Basic.Util.to_string in

  (* Get with example.org base_url *)
  let* result2 =
    Miiify.Controller.get_annotation ~db ~container_id ~annotation_id
      ~base_url:"https://example.org"
  in
  let json2 = Yojson.Basic.from_string result2 in
  let id2 = Yojson.Basic.Util.member "id" json2 |> Yojson.Basic.Util.to_string in

  Alcotest.(check string) "localhost ID correct"
    "http://localhost:10000/test-canvas/anno-1" id1;
  Alcotest.(check string) "example.org ID correct"
    "https://example.org/test-canvas/anno-1" id2;
  Alcotest.(check bool) "IDs differ with different base_url" true (id1 <> id2);

  Lwt.return_unit

let () =
  Lwt_main.run @@
  run "Miiify Response Tests"
    [
      ( "API Helpers",
        [ test_case "JSON extension stripping" `Quick test_json_extension_stripping ]
      );
      ( "ID Injection",
        [
          test_case "annotation id" `Quick test_id_annotation;
          test_case "container id" `Quick test_id_container;
          test_case "collection ids" `Quick test_id_collection;
          test_case "page id" `Quick test_id_page;
          test_case "base url variation" `Quick test_id_base_url_variation;
        ]
      );
    ]
