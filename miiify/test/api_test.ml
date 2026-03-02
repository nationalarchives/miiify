open Lwt.Syntax
open Alcotest_lwt

open Test_support

let seed_container ~db ~container_id ~count =
  let container_json = {|{"type":"AnnotationCollection","label":"My Canvas"}|} in
  let* () =
    Miiify.Db.set ~db ~key:[ container_id; "metadata" ] ~data:container_json
      ~message:"Create container"
  in
  let rec loop i =
    if i >= count then Lwt.return_unit
    else
      let slug = Printf.sprintf "note-%02d" i in
      let annotation =
        Printf.sprintf
          {|{"type":"Annotation","motivation":"commenting","body":{"type":"TextualBody","value":"Note %d"},"target":"https://example.com/iiif/canvas/1"}|}
          i
      in
      let* () =
        Miiify.Db.set ~db ~key:[ container_id; "collection"; slug ] ~data:annotation
          ~message:("Import " ^ slug)
      in
      loop (i + 1)
  in
  loop 0

let seed_container_with_slugs ~db ~container_id ~slugs =
  let container_json = {|{"type":"AnnotationCollection","label":"My Canvas"}|} in
  let* () =
    Miiify.Db.set ~db ~key:[ container_id; "metadata" ] ~data:container_json
      ~message:"Create container"
  in
  Lwt_list.iteri_s
    (fun i slug ->
      let annotation =
        Printf.sprintf
          {|{"type":"Annotation","motivation":"commenting","body":{"type":"TextualBody","value":"Note %d"},"target":"https://example.com/iiif/canvas/1"}|}
          i
      in
      Miiify.Db.set ~db ~key:[ container_id; "collection"; slug ] ~data:annotation
        ~message:("Import " ^ slug))
    slugs

(* Create app routes for testing *)
let create_app db base_url page_limit =
  Dream.router [
    (* Match the exact order from serve.ml *)
    Dream.get "/" Miiify.Api.get_status;
    Dream.get "/version" Miiify.Api.get_version;
    Dream.get "/:container_id/" (Miiify.Api.get_annotations base_url page_limit db);
    Dream.get "/:container_id/:annotation_id" (Miiify.Api.get_annotation base_url db);
  ]

(* Test: GET / (status endpoint) *)
let test_status_endpoint _switch () =
  let* db = create_test_db_from_files "status" in
  let app = create_app db "http://localhost:10000" 200 in
  
  let response = Dream.test app (Dream.request ~target:"/" "") in
  let* body = Dream.body response in
  
  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  Alcotest.(check bool) "contains status:ok" true (String.length body > 0);
  
  Lwt.return_unit

(* Test: GET /version *)
let test_version_endpoint _switch () =
  let* db = create_test_db_from_files "version" in
  let app = create_app db "http://localhost:10000" 200 in
  
  let req = Dream.request ~target:"/version" "" in
  let response = Dream.test app req in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in
  let version = Yojson.Basic.Util.member "version" json |> Yojson.Basic.Util.to_string in
  
  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  (* Check version is non-empty and matches semver pattern (e.g., "2.0.1") *)
  Alcotest.(check bool) "version is non-empty" true (String.length version > 0);
  Alcotest.(check bool) "version matches semver pattern" true 
    (Str.string_match (Str.regexp "^[0-9]+\\.[0-9]+\\.[0-9]+") version 0);
  
  Lwt.return_unit

(* Test: GET /:container/:annotation (single annotation) *)
let test_get_annotation _switch () =
  let* db = create_test_db_from_files "get_annotation" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 200 in
  
  let response = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/highlight-1" container_id) "") in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in
  
  (* Check status *)
  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  
  (* Check ID was injected *)
  let id = Yojson.Basic.Util.member "id" json |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "ID correct" "http://localhost:10000/my-canvas/highlight-1" id;
  
  (* Check body value *)
  let body_value = Yojson.Basic.Util.member "body" json 
                  |> Yojson.Basic.Util.member "value" 
                  |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "body value" "Important passage" body_value;
  
  Lwt.return_unit

(* Test: GET /:container/:annotation.json (with .json extension) *)
let test_get_annotation_with_json_ext _switch () =
  let* db = create_test_db_from_files "get_annotation_json" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 200 in
  
  let response = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/highlight-1.json" container_id) "") in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in
  
  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  
  let id = Yojson.Basic.Util.member "id" json |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "ID correct (no .json)" "http://localhost:10000/my-canvas/highlight-1" id;
  
  Lwt.return_unit

(* Test: GET /:container/?page=0 (first page explicitly) *)
let test_get_collection _switch () =
  let* db = create_test_db_from_files "get_collection" in
  let container_id = "my-canvas" in
  let base_url = "http://localhost:10000" in
  let app = create_app db base_url 1 in
  
  (* Use explicit page=0 to get collection - this works reliably *)
  let response = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/?page=0" container_id) "") in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in
  
  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  
  (* Check it's an AnnotationPage *)
  assert_type json "AnnotationPage";

  let id = Yojson.Basic.Util.member "id" json |> Yojson.Basic.Util.to_string in
  Alcotest.(check bool) "id includes page=0" true (String.contains id '?');
  Alcotest.(check bool) "id includes page=0" true (String.ends_with ~suffix:"page=0" id);

  let start_index = Yojson.Basic.Util.member "startIndex" json |> Yojson.Basic.Util.to_int in
  Alcotest.(check int) "startIndex is 0" 0 start_index;

  let part_of = Yojson.Basic.Util.member "partOf" json in
  let part_of_id = Yojson.Basic.Util.member "id" part_of |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "partOf.id" (base_url ^ "/" ^ container_id ^ "/") part_of_id;
  let part_of_total = Yojson.Basic.Util.member "total" part_of |> Yojson.Basic.Util.to_int in
  Alcotest.(check int) "partOf.total" 2 part_of_total;
  
  (* Check items exist *)
  let items = Yojson.Basic.Util.member "items" json |> Yojson.Basic.Util.to_list in
  Alcotest.(check int) "page has 1 item" 1 (List.length items);

  let next = Yojson.Basic.Util.member "next" json in
  (match next with
  | `String s -> Alcotest.(check bool) "next includes page=1" true (String.ends_with ~suffix:"page=1" s)
  | _ -> Alcotest.fail "expected next link on page=0");

  let prev = Yojson.Basic.Util.member "prev" json in
  Alcotest.(check bool) "prev is null on page=0" true (prev = `Null);
  
  Lwt.return_unit

(* Test: GET /:container/?page=1 (specific page)
   Use a small page_limit so that page 1 exists with 2 annotations. *)
let test_get_page _switch () =
  let* db = create_test_db_from_files "get_page" in
  let container_id = "my-canvas" in
  let base_url = "http://localhost:10000" in
  let app = create_app db base_url 1 in
  
  let response = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/?page=1" container_id) "") in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in
  
  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  
  (* Check it's an AnnotationPage *)
  assert_type json "AnnotationPage";

  let start_index = Yojson.Basic.Util.member "startIndex" json |> Yojson.Basic.Util.to_int in
  Alcotest.(check int) "startIndex is 1" 1 start_index;

  let part_of = Yojson.Basic.Util.member "partOf" json in
  let part_of_id = Yojson.Basic.Util.member "id" part_of |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "partOf.id" (base_url ^ "/" ^ container_id ^ "/") part_of_id;
  let part_of_total = Yojson.Basic.Util.member "total" part_of |> Yojson.Basic.Util.to_int in
  Alcotest.(check int) "partOf.total" 2 part_of_total;

  let items = Yojson.Basic.Util.member "items" json |> Yojson.Basic.Util.to_list in
  Alcotest.(check int) "page has 1 item" 1 (List.length items);

  let next = Yojson.Basic.Util.member "next" json in
  Alcotest.(check bool) "next is null on last page" true (next = `Null);

  let prev = Yojson.Basic.Util.member "prev" json in
  (match prev with
  | `String s -> Alcotest.(check bool) "prev includes page=0" true (String.ends_with ~suffix:"page=0" s)
  | _ -> Alcotest.fail "expected prev link on page=1");
  
  Lwt.return_unit

(* Test: GET /:container/ (no page query parameter) returns AnnotationCollection *)
let test_get_collection_without_page _switch () =
  let* db = create_test_db_from_files "get_collection_no_page" in
  let container_id = "my-canvas" in
  let base_url = "http://localhost:10000" in
  let app = create_app db base_url 1 in

  let response = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/" container_id) "") in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in

  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
    (* The collection endpoint returns AnnotationCollection with paging fields *)
    assert_type json "AnnotationCollection";

  let total = Yojson.Basic.Util.member "total" json |> Yojson.Basic.Util.to_int in
  Alcotest.(check int) "total" 2 total;

  let first = Yojson.Basic.Util.member "first" json in
  assert_type first "AnnotationPage";
  let first_items = Yojson.Basic.Util.member "items" first |> Yojson.Basic.Util.to_list in
  Alcotest.(check int) "first page has 1 item" 1 (List.length first_items);

  let first_next = Yojson.Basic.Util.member "next" first in
  (match first_next with
  | `String s -> Alcotest.(check bool) "first.next includes page=1" true (String.ends_with ~suffix:"page=1" s)
  | _ -> Alcotest.fail "expected first.next link");

  let last = Yojson.Basic.Util.member "last" json in
  (match last with
  | `String s -> Alcotest.(check bool) "last includes page=1" true (String.ends_with ~suffix:"page=1" s)
  | _ -> Alcotest.fail "expected last link");

  Lwt.return_unit

(* Test: Out-of-range page returns 404 *)
let test_get_page_out_of_range _switch () =
  let* db = create_test_db_from_files "get_page_out_of_range" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 1 in

  let response = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/?page=2" container_id) "") in
  let* body = Dream.body response in

  Alcotest.(check int) "status 404" 404 (Dream.status_to_int (Dream.status response));
  Alcotest.(check bool) "body mentions Page not found" true (string_contains body "Page not found");

  Lwt.return_unit

let test_zero_page_limit_does_not_crash _switch () =
  let* db = create_test_db_from_files "zero_page_limit" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 0 in

  let response =
    Dream.test app
      (Dream.request ~target:(Printf.sprintf "/%s/?page=0" container_id) "")
  in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in

  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  assert_type json "AnnotationPage";
  let items = Yojson.Basic.Util.member "items" json |> Yojson.Basic.Util.to_list in
  Alcotest.(check int) "items empty with limit=0" 0 (List.length items);

  Lwt.return_unit

(* Test: AnnotationPage with no pagination links when all items fit on one page *)
let test_page_no_navigation_when_all_fit _switch () =
  let* db = create_test_db_from_files "page_no_nav" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 200 in

  let response = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/?page=0" container_id) "") in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in

  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  assert_type json "AnnotationPage";

  let items = Yojson.Basic.Util.member "items" json |> Yojson.Basic.Util.to_list in
  Alcotest.(check int) "all items on page" 2 (List.length items);

  (* When all items fit on one page, there should be no next/prev links *)
  let next = Yojson.Basic.Util.member "next" json in
  Alcotest.(check bool) "next is null when all fit" true (next = `Null);

  let prev = Yojson.Basic.Util.member "prev" json in
  Alcotest.(check bool) "prev is null on page 0" true (prev = `Null);

  Lwt.return_unit

(* Test: AnnotationCollection with no pagination links when all items fit *)
let test_collection_no_navigation_when_all_fit _switch () =
  let* db = create_test_db_from_files "collection_no_nav" in
  let container_id = "my-canvas" in
  let base_url = "http://localhost:10000" in
  let app = create_app db base_url 200 in

  let response = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/" container_id) "") in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in

  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  assert_type json "AnnotationCollection";

  let total = Yojson.Basic.Util.member "total" json |> Yojson.Basic.Util.to_int in
  Alcotest.(check int) "total" 2 total;

  let first = Yojson.Basic.Util.member "first" json in
  assert_type first "AnnotationPage";
  let first_items = Yojson.Basic.Util.member "items" first |> Yojson.Basic.Util.to_list in
  Alcotest.(check int) "first page has all items" 2 (List.length first_items);

  (* When all items fit, first.next should be null *)
  let first_next = Yojson.Basic.Util.member "next" first in
  Alcotest.(check bool) "first.next is null when all fit" true (first_next = `Null);

  (* When all items fit, last should be null (only page 0 exists) *)
  let last = Yojson.Basic.Util.member "last" json in
  Alcotest.(check bool) "last is null when all fit" true (last = `Null);

  Lwt.return_unit

let test_items_are_lexicographically_ordered_by_id _switch () =
  let* db = create_test_db_pack "items_lex_order" in
  let container_id = "my-canvas" in
  let base_url = "http://localhost:10000" in
  let page_limit = 50 in

  (* Insert out of order; storage layer should return lexicographic by slug. *)
  let* () =
    seed_container_with_slugs ~db ~container_id ~slugs:[ "b"; "a"; "c" ]
  in
  let app = create_app db base_url page_limit in

  let response =
    Dream.test app
      (Dream.request ~target:(Printf.sprintf "/%s/?page=0" container_id) "")
  in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in

  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  assert_type json "AnnotationPage";

  let items = Yojson.Basic.Util.member "items" json |> Yojson.Basic.Util.to_list in
  Alcotest.(check int) "3 items" 3 (List.length items);

  let ids =
    List.map
      (fun item -> Yojson.Basic.Util.member "id" item |> Yojson.Basic.Util.to_string)
      items
  in
  Alcotest.(check (list string)) "ids are lexicographically ordered"
    [ base_url ^ "/" ^ container_id ^ "/a";
      base_url ^ "/" ^ container_id ^ "/b";
      base_url ^ "/" ^ container_id ^ "/c" ]
    ids;

  Lwt.return_unit

let test_page_boundary_exact_limit _switch () =
  let* db = create_test_db_pack "page_boundary_exact_limit" in
  let container_id = "my-canvas" in
  let base_url = "http://localhost:10000" in
  let page_limit = 2 in

  let* () = seed_container ~db ~container_id ~count:2 in
  let app = create_app db base_url page_limit in

  let response =
    Dream.test app
      (Dream.request ~target:(Printf.sprintf "/%s/?page=0" container_id) "")
  in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in

  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  assert_type json "AnnotationPage";

  let items = Yojson.Basic.Util.member "items" json |> Yojson.Basic.Util.to_list in
  Alcotest.(check int) "items = page_limit" 2 (List.length items);

  let part_of = Yojson.Basic.Util.member "partOf" json in
  let total = Yojson.Basic.Util.member "total" part_of |> Yojson.Basic.Util.to_int in
  Alcotest.(check int) "partOf.total" 2 total;

  let next = Yojson.Basic.Util.member "next" json in
  Alcotest.(check bool) "next null when exactly full" true (next = `Null);

  let prev = Yojson.Basic.Util.member "prev" json in
  Alcotest.(check bool) "prev null on page 0" true (prev = `Null);

  Lwt.return_unit

let test_page_boundary_limit_plus_one _switch () =
  let* db = create_test_db_pack "page_boundary_limit_plus_one" in
  let container_id = "my-canvas" in
  let base_url = "http://localhost:10000" in
  let page_limit = 2 in

  let* () = seed_container ~db ~container_id ~count:3 in
  let app = create_app db base_url page_limit in

  let response0 =
    Dream.test app
      (Dream.request ~target:(Printf.sprintf "/%s/?page=0" container_id) "")
  in
  let* body0 = Dream.body response0 in
  let json0 = Yojson.Basic.from_string body0 in

  Alcotest.(check int) "status 200" 200
    (Dream.status_to_int (Dream.status response0));
  assert_type json0 "AnnotationPage";
  let items0 = Yojson.Basic.Util.member "items" json0 |> Yojson.Basic.Util.to_list in
  Alcotest.(check int) "page 0 has 2 items" 2 (List.length items0);

  let next0 = Yojson.Basic.Util.member "next" json0 in
  (match next0 with
  | `String s ->
      Alcotest.(check bool) "next includes page=1" true
        (String.ends_with ~suffix:"page=1" s)
  | _ -> Alcotest.fail "expected next link on page 0");

  let response1 =
    Dream.test app
      (Dream.request ~target:(Printf.sprintf "/%s/?page=1" container_id) "")
  in
  let* body1 = Dream.body response1 in
  let json1 = Yojson.Basic.from_string body1 in

  Alcotest.(check int) "status 200" 200
    (Dream.status_to_int (Dream.status response1));
  assert_type json1 "AnnotationPage";

  let start_index =
    Yojson.Basic.Util.member "startIndex" json1 |> Yojson.Basic.Util.to_int
  in
  Alcotest.(check int) "page 1 startIndex" 2 start_index;

  let items1 = Yojson.Basic.Util.member "items" json1 |> Yojson.Basic.Util.to_list in
  Alcotest.(check int) "page 1 has 1 item" 1 (List.length items1);

  let prev1 = Yojson.Basic.Util.member "prev" json1 in
  (match prev1 with
  | `String s ->
      Alcotest.(check bool) "prev includes page=0" true
        (String.ends_with ~suffix:"page=0" s)
  | _ -> Alcotest.fail "expected prev link on page 1");

  let next1 = Yojson.Basic.Util.member "next" json1 in
  Alcotest.(check bool) "next null on last page" true (next1 = `Null);

  Lwt.return_unit

let test_page_boundary_two_full_pages _switch () =
  let* db = create_test_db_pack "page_boundary_two_full_pages" in
  let container_id = "my-canvas" in
  let base_url = "http://localhost:10000" in
  let page_limit = 2 in

  let* () = seed_container ~db ~container_id ~count:4 in
  let app = create_app db base_url page_limit in

  let response1 =
    Dream.test app
      (Dream.request ~target:(Printf.sprintf "/%s/?page=1" container_id) "")
  in
  let* body1 = Dream.body response1 in
  let json1 = Yojson.Basic.from_string body1 in

  Alcotest.(check int) "status 200" 200
    (Dream.status_to_int (Dream.status response1));
  assert_type json1 "AnnotationPage";

  let items1 = Yojson.Basic.Util.member "items" json1 |> Yojson.Basic.Util.to_list in
  Alcotest.(check int) "page 1 has 2 items" 2 (List.length items1);

  let prev1 = Yojson.Basic.Util.member "prev" json1 in
  (match prev1 with
  | `String s ->
      Alcotest.(check bool) "prev includes page=0" true
        (String.ends_with ~suffix:"page=0" s)
  | _ -> Alcotest.fail "expected prev link on page 1");

  let next1 = Yojson.Basic.Util.member "next" json1 in
  Alcotest.(check bool) "next null on last page" true (next1 = `Null);

  Lwt.return_unit

let test_empty_container_page_zero_exists _switch () =
  let* db = create_test_db_pack "empty_container_page_zero_exists" in
  let container_id = "empty-canvas" in
  let base_url = "http://localhost:10000" in
  let page_limit = 2 in

  let* () = seed_container ~db ~container_id ~count:0 in
  let app = create_app db base_url page_limit in

  let response =
    Dream.test app
      (Dream.request ~target:(Printf.sprintf "/%s/?page=0" container_id) "")
  in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in

  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  assert_type json "AnnotationPage";

  let items = Yojson.Basic.Util.member "items" json |> Yojson.Basic.Util.to_list in
  Alcotest.(check int) "items empty" 0 (List.length items);

  let next = Yojson.Basic.Util.member "next" json in
  Alcotest.(check bool) "next is null" true (next = `Null);

  let prev = Yojson.Basic.Util.member "prev" json in
  Alcotest.(check bool) "prev is null" true (prev = `Null);

  let part_of = Yojson.Basic.Util.member "partOf" json in
  let total = Yojson.Basic.Util.member "total" part_of in
  Alcotest.(check bool) "partOf.total omitted" true (total = `Null);

  Lwt.return_unit

let test_empty_container_collection_is_consistent _switch () =
  let* db = create_test_db_pack "empty_container_collection_is_consistent" in
  let container_id = "empty-canvas" in
  let base_url = "http://localhost:10000" in
  let page_limit = 2 in

  let* () = seed_container ~db ~container_id ~count:0 in
  let app = create_app db base_url page_limit in

  let response =
    Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/" container_id) "")
  in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in

  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  assert_type json "AnnotationCollection";

  let total = Yojson.Basic.Util.member "total" json in
  Alcotest.(check bool) "total omitted" true (total = `Null);

  let last = Yojson.Basic.Util.member "last" json in
  Alcotest.(check bool) "last is null" true (last = `Null);

  let first = Yojson.Basic.Util.member "first" json in
  assert_type first "AnnotationPage";
  let first_id = Yojson.Basic.Util.member "id" first |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "first.id" (base_url ^ "/" ^ container_id ^ "/?page=0") first_id;

  let items = Yojson.Basic.Util.member "items" first |> Yojson.Basic.Util.to_list in
  Alcotest.(check int) "first.items empty" 0 (List.length items);

  let first_next = Yojson.Basic.Util.member "next" first in
  Alcotest.(check bool) "first.next is null" true (first_next = `Null);

  Lwt.return_unit

let test_paging_returns_distinct_expected_items _switch () =
  let* db = create_test_db_from_files "paging_distinct_items" in
  let container_id = "my-canvas" in
  let base_url = "http://localhost:10000" in
  let app = create_app db base_url 1 in

  let fetch_item_id page =
    let response =
      Dream.test app
        (Dream.request
           ~target:(Printf.sprintf "/%s/?page=%d" container_id page)
           "")
    in
    let* body = Dream.body response in
    let json = Yojson.Basic.from_string body in
    let items = Yojson.Basic.Util.member "items" json |> Yojson.Basic.Util.to_list in
    match items with
    | [item] ->
        let id = Yojson.Basic.Util.member "id" item |> Yojson.Basic.Util.to_string in
        Lwt.return id
    | _ -> Lwt.fail_with "expected exactly one item per page"
  in

  let* id0 = fetch_item_id 0 in
  let* id1 = fetch_item_id 1 in

  Alcotest.(check bool) "page 0 and 1 are different" true (not (String.equal id0 id1));

  let expected_a = base_url ^ "/" ^ container_id ^ "/highlight-1" in
  let expected_b = base_url ^ "/" ^ container_id ^ "/comment-1" in

  let is_expected id = String.equal id expected_a || String.equal id expected_b in
  Alcotest.(check bool) "page 0 item is expected" true (is_expected id0);
  Alcotest.(check bool) "page 1 item is expected" true (is_expected id1);
  Alcotest.(check bool) "both expected items present" true ((id0 = expected_a && id1 = expected_b) || (id0 = expected_b && id1 = expected_a));

  Lwt.return_unit

(* Test: 404 for non-existent annotation *)
let test_not_found _switch () =
  let* db = create_test_db_from_files "not_found" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 200 in
  
  let response = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/does-not-exist" container_id) "") in
  
  Alcotest.(check int) "status 404" 404 (Dream.status_to_int (Dream.status response));
  
  Lwt.return_unit

(* Test: ETag support *)
let test_etag _switch () =
  let* db = create_test_db_from_files "etag" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 200 in
  
  (* First request - get ETag *)
  let response1 = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/highlight-1" container_id) "") in
  let etag = Dream.header response1 "ETag" in
  
  Alcotest.(check bool) "has ETag" true (Option.is_some etag);
  
  (* Second request with If-None-Match - should get 304 *)
  let etag_value = Option.get etag in
  let request2 = Dream.request ~target:(Printf.sprintf "/%s/highlight-1" container_id) "" in
  Dream.set_header request2 "If-None-Match" etag_value;
  let response2 = Dream.test app request2 in
  
  Alcotest.(check int) "status 304" 304 (Dream.status_to_int (Dream.status response2));
  
  Lwt.return_unit

let test_etag_collection _switch () =
  let* db = create_test_db_from_files "etag_collection" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 200 in

  let response1 = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/" container_id) "") in
  let etag = Dream.header response1 "ETag" in
  Alcotest.(check bool) "has ETag" true (Option.is_some etag);

  let request2 = Dream.request ~target:(Printf.sprintf "/%s/" container_id) "" in
  Dream.set_header request2 "If-None-Match" (Option.get etag);
  let response2 = Dream.test app request2 in
  Alcotest.(check int) "status 304" 304 (Dream.status_to_int (Dream.status response2));

  Lwt.return_unit

let test_etag_does_not_cross_pages _switch () =
  let* db = create_test_db_from_files "etag_cross_pages" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 1 in

  let response_page0 =
    Dream.test app
      (Dream.request ~target:(Printf.sprintf "/%s/?page=0" container_id) "")
  in
  let etag0 = Dream.header response_page0 "ETag" in
  Alcotest.(check bool) "page 0 has ETag" true (Option.is_some etag0);

  let request_page1 =
    Dream.request ~target:(Printf.sprintf "/%s/?page=1" container_id) ""
  in
  Dream.set_header request_page1 "If-None-Match" (Option.get etag0);
  let response_page1 = Dream.test app request_page1 in
  Alcotest.(check int)
    "page 1 should not be 304 from page 0 etag"
    200 (Dream.status_to_int (Dream.status response_page1));

  Lwt.return_unit

let test_negative_page_returns_404 _switch () =
  let* db = create_test_db_from_files "negative_page" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 1 in

  let response = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/?page=-1" container_id) "") in
  Alcotest.(check int) "status 404" 404 (Dream.status_to_int (Dream.status response));

  Lwt.return_unit

let test_missing_container_returns_404 _switch () =
  let* db = create_test_db_from_files "missing_container" in
  let app = create_app db "http://localhost:10000" 200 in

  let response1 = Dream.test app (Dream.request ~target:"/does-not-exist" "") in
  Alcotest.(check int) "GET /missing status 404" 404 (Dream.status_to_int (Dream.status response1));

  let response2 = Dream.test app (Dream.request ~target:"/does-not-exist/?page=0" "") in
  Alcotest.(check int) "GET /missing/?page=0 status 404" 404 (Dream.status_to_int (Dream.status response2));

  Lwt.return_unit

let test_unknown_route_404 _switch () =
  let* db = create_test_db_from_files "unknown_route" in
  let app = create_app db "http://localhost:10000" 200 in

  let response = Dream.test app (Dream.request ~target:"/no/such/route" "") in
  Alcotest.(check int) "status 404" 404 (Dream.status_to_int (Dream.status response));

  Lwt.return_unit

let test_container_without_trailing_slash_404 _switch () =
  let* db = create_test_db_from_files "no_trailing_slash" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 200 in

  (* Verify container exists with trailing slash *)
  let response_with_slash = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/" container_id) "") in
  Alcotest.(check int) "GET /:container/ returns 200" 200 (Dream.status_to_int (Dream.status response_with_slash));

  (* Verify without trailing slash returns 404 *)
  let response_without_slash = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s" container_id) "") in
  Alcotest.(check int) "GET /:container returns 404" 404 (Dream.status_to_int (Dream.status response_without_slash));

  Lwt.return_unit

let test_malformed_page_non_numeric _switch () =
  let* db = create_test_db_from_files "malformed_page_non_numeric" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 200 in

  (* Non-numeric page should default to 0 *)
  let response = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/?page=not-a-number" container_id) "") in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in

  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  assert_type json "AnnotationPage";
  
  let start_index = Yojson.Basic.Util.member "startIndex" json |> Yojson.Basic.Util.to_int in
  Alcotest.(check int) "startIndex 0 (defaulted)" 0 start_index;

  Lwt.return_unit

let test_malformed_page_huge_number _switch () =
  let* db = create_test_db_from_files "malformed_page_huge" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 200 in

  (* Extremely large page number should return 404 (out of range) *)
  let response = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/?page=999999999" container_id) "") in
  Alcotest.(check int) "status 404" 404 (Dream.status_to_int (Dream.status response));

  Lwt.return_unit

(* Main test suite *)
let () =
  Lwt_main.run @@
  run "Miiify HTTP API Tests" [
    ("Basic Endpoints", [ 
      test_case "GET /" `Quick test_status_endpoint;
      test_case "GET /version" `Quick test_version_endpoint;
    ]);
    ("Annotation Retrieval", [ 
      test_case "GET /:container/:annotation" `Quick test_get_annotation;
      test_case "GET /:container/:annotation.json" `Quick test_get_annotation_with_json_ext;
      test_case "404 for non-existent" `Quick test_not_found;
    ]);
    ("Collection Endpoints", [ 
      test_case "GET /:container/" `Quick test_get_collection_without_page;
      test_case "GET /:container/?page=0" `Quick test_get_collection;
      test_case "GET /:container/?page=1" `Quick test_get_page;
      test_case "404 for out-of-range page" `Quick test_get_page_out_of_range;
      test_case "page has no nav when all items fit" `Quick test_page_no_navigation_when_all_fit;
      test_case "collection has no nav when all items fit" `Quick test_collection_no_navigation_when_all_fit;
      test_case "items ordered lexicographically" `Quick test_items_are_lexicographically_ordered_by_id;
      test_case "boundary: exact page_limit" `Quick test_page_boundary_exact_limit;
      test_case "boundary: page_limit+1" `Quick test_page_boundary_limit_plus_one;
      test_case "boundary: two full pages" `Quick test_page_boundary_two_full_pages;
      test_case "empty container: page=0 exists" `Quick test_empty_container_page_zero_exists;
      test_case "empty container: collection consistent" `Quick test_empty_container_collection_is_consistent;
    ]);
    ("HTTP Features", [
      test_case "ETag support" `Quick test_etag;
      test_case "ETag 304 for collection" `Quick test_etag_collection;
      test_case "ETag does not cross pages" `Quick test_etag_does_not_cross_pages;
      test_case "negative page returns 404" `Quick test_negative_page_returns_404;
      test_case "missing container returns 404" `Quick test_missing_container_returns_404;
      test_case "unknown route returns 404" `Quick test_unknown_route_404;
      test_case "container without trailing slash returns 404" `Quick test_container_without_trailing_slash_404;
      test_case "page_limit=0 does not crash" `Quick test_zero_page_limit_does_not_crash;
      test_case "paging yields distinct expected" `Quick test_paging_returns_distinct_expected_items;
    ]);
    ("Malformed Input", [
      test_case "page=non-numeric defaults to 0" `Quick test_malformed_page_non_numeric;
      test_case "page=huge number returns 404" `Quick test_malformed_page_huge_number;
    ]);
  ]
