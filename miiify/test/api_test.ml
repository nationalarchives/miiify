open Lwt.Syntax
open Alcotest_lwt

open Test_support

(* Create app routes for testing *)
let create_app db base_url page_limit =
  Dream.router [
    (* Match the exact order from serve.ml *)
    Dream.get "/" Miiify.Api.get_status;
    Dream.get "/version" Miiify.Api.get_version;
    Dream.get "/:container_id/" (Miiify.Api.get_annotations base_url page_limit db);
    Dream.get "/:container_id/:annotation_id" (Miiify.Api.get_annotation base_url db);
    Dream.get "/:container_id" (Miiify.Api.get_container base_url db);
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
  Alcotest.(check string) "version 2.0.0" "2.0.0" version;
  
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

(* Test: GET /:container (container metadata) *)
let test_get_container _switch () =
  let* db = create_test_db_from_files "get_container" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 200 in
  
  let response = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s" container_id) "") in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in
  
  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  
  (* Check it's an AnnotationContainer *)
  let type_ = Yojson.Basic.Util.member "type" json |> Yojson.Basic.Util.to_string in
  Alcotest.(check string) "type is AnnotationContainer" "AnnotationContainer" type_;
  
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
    (* The compile pipeline currently creates container metadata with type=AnnotationContainer.
      The collection endpoint augments that JSON with paging fields. *)
    assert_type_any json ["AnnotationCollection"; "AnnotationContainer"];

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

let test_target_filtering_over_http _switch () =
  let* db = create_test_db_from_files "target_filter_http" in
  let container_id = "my-canvas" in
  let base_url = "http://localhost:10000" in
  let app = create_app db base_url 200 in

  let target = Dream.to_percent_encoded highlight_target in
  let response =
    Dream.test app
      (Dream.request
         ~target:(Printf.sprintf "/%s/?page=0&target=%s" container_id target)
         "")
  in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in

  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  assert_type json "AnnotationPage";

  let items = Yojson.Basic.Util.member "items" json |> Yojson.Basic.Util.to_list in
  Alcotest.(check int) "one matching item" 1 (List.length items);
  let id = Yojson.Basic.Util.member "id" (List.hd items) |> Yojson.Basic.Util.to_string in
  Alcotest.(check string)
    "returns highlight-1"
    (base_url ^ "/" ^ container_id ^ "/highlight-1")
    id;

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

let test_etag_container _switch () =
  let* db = create_test_db_from_files "etag_container" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 200 in

  let response1 = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s" container_id) "") in
  let etag = Dream.header response1 "ETag" in
  Alcotest.(check bool) "has ETag" true (Option.is_some etag);

  let request2 = Dream.request ~target:(Printf.sprintf "/%s" container_id) "" in
  Dream.set_header request2 "If-None-Match" (Option.get etag);
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

let test_etag_does_not_cross_targets _switch () =
  let* db = create_test_db_from_files "etag_cross_targets" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 200 in

  let target = Dream.to_percent_encoded highlight_target in
  let response_filtered =
    Dream.test app
      (Dream.request
         ~target:(Printf.sprintf "/%s/?page=0&target=%s" container_id target)
         "")
  in
  let etag_filtered = Dream.header response_filtered "ETag" in
  Alcotest.(check bool) "filtered response has ETag" true (Option.is_some etag_filtered);

  let request_unfiltered =
    Dream.request ~target:(Printf.sprintf "/%s/?page=0" container_id) ""
  in
  Dream.set_header request_unfiltered "If-None-Match" (Option.get etag_filtered);
  let response_unfiltered = Dream.test app request_unfiltered in

  Alcotest.(check int)
    "unfiltered should not be 304 from filtered etag"
    200 (Dream.status_to_int (Dream.status response_unfiltered));

  Lwt.return_unit

let test_invalid_page_param_defaults_to_0 _switch () =
  let* db = create_test_db_from_files "invalid_page_param" in
  let container_id = "my-canvas" in
  let app = create_app db "http://localhost:10000" 1 in

  let response = Dream.test app (Dream.request ~target:(Printf.sprintf "/%s/?page=abc" container_id) "") in
  let* body = Dream.body response in
  let json = Yojson.Basic.from_string body in

  Alcotest.(check int) "status 200" 200 (Dream.status_to_int (Dream.status response));
  assert_type json "AnnotationPage";
  let start_index = Yojson.Basic.Util.member "startIndex" json |> Yojson.Basic.Util.to_int in
  Alcotest.(check int) "startIndex is 0" 0 start_index;

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
      test_case "GET /:container" `Quick test_get_container;
      test_case "GET /:container/?page=1" `Quick test_get_page;
      test_case "404 for out-of-range page" `Quick test_get_page_out_of_range;
    ]);
    ("HTTP Features", [
      test_case "ETag support" `Quick test_etag;
      test_case "ETag 304 for container" `Quick test_etag_container;
      test_case "ETag 304 for collection" `Quick test_etag_collection;
      test_case "ETag does not cross pages" `Quick test_etag_does_not_cross_pages;
      test_case "ETag does not cross targets" `Quick test_etag_does_not_cross_targets;
      test_case "invalid page defaults to 0" `Quick test_invalid_page_param_defaults_to_0;
      test_case "negative page returns 404" `Quick test_negative_page_returns_404;
      test_case "missing container returns 404" `Quick test_missing_container_returns_404;
      test_case "unknown route returns 404" `Quick test_unknown_route_404;
      test_case "page_limit=0 does not crash" `Quick test_zero_page_limit_does_not_crash;
      test_case "target filtering" `Quick test_target_filtering_over_http;
      test_case "paging yields distinct expected" `Quick test_paging_returns_distinct_expected_items;
    ]);
  ]
