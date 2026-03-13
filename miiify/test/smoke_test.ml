open Lwt.Syntax
open Alcotest_lwt

open Test_support

let create_app db base_url page_limit =
  Dream.router
    [
      Dream.get "/" Miiify.Api.get_status;
      Dream.get "/version" Miiify.Api.get_version;
      Dream.get "/:container_id/" (Miiify.Api.get_annotations base_url page_limit db);
      Dream.get "/:container_id/:annotation_id"
        (Miiify.Api.get_annotation base_url db);
    ]

let test_import_compile_then_http _switch () =
  let ws = make_temp_workspace "smoke" in

  let _ =
    write_annotation_file ~annotations_dir:ws.annotations_dir
      ~container_id:"my-canvas" ~slug:"note-0002" ~contents:highlight_annotation
  in
  let _ =
    write_annotation_file ~annotations_dir:ws.annotations_dir
      ~container_id:"my-canvas" ~slug:"note-0010" ~contents:comment_annotation
  in

  let import_result =
    run_miiify_import ~annotations_dir:ws.annotations_dir ~git_repo:ws.git_repo
  in
  Alcotest.(check int) "import exit code" 0 import_result;

  let compile_result = run_miiify_compile ~git_repo:ws.git_repo ~pack_repo:ws.pack_repo in
  Alcotest.(check int) "compile exit code" 0 compile_result;

  let* db = Miiify.Model.create ~repository_name:ws.pack_repo in
  let base_url = "http://localhost:10000" in
  let app = create_app db base_url 10 in

  (* Status *)
  let status_resp = Dream.test app (Dream.request ~target:"/" "") in
  Alcotest.(check int) "GET / status" 200
    (Dream.status_to_int (Dream.status status_resp));

  (* Collection with first page *)
  let container_resp =
    Dream.test app (Dream.request ~target:"/my-canvas/" "")
  in
  let* container_body = Dream.body container_resp in
  Alcotest.(check int) "GET /my-canvas/ status" 200
    (Dream.status_to_int (Dream.status container_resp));
  let container_json = Yojson.Basic.from_string container_body in
  assert_type container_json "AnnotationCollection";

  (* Page 0 *)
  let page_resp =
    Dream.test app (Dream.request ~target:"/my-canvas/?page=0" "")
  in
  let* page_body = Dream.body page_resp in
  Alcotest.(check int) "GET /my-canvas/?page=0 status" 200
    (Dream.status_to_int (Dream.status page_resp));
  let page_json = Yojson.Basic.from_string page_body in
  assert_type page_json "AnnotationPage";
  let items = Yojson.Basic.Util.member "items" page_json |> Yojson.Basic.Util.to_list in
  Alcotest.(check bool) "page has items" true (List.length items > 0);

  Lwt.return_unit

(* Test: annotation with existing id is warned but accepted without --validate *)
let test_import_with_id_no_validate _switch () =
  let ws = make_temp_workspace "id-no-validate" in
  let _ =
    write_annotation_file ~annotations_dir:ws.annotations_dir
      ~container_id:"my-canvas" ~slug:"anno-with-id" ~contents:annotation_with_id
  in
  let result =
    run_miiify_import ~annotations_dir:ws.annotations_dir ~git_repo:ws.git_repo
  in
  Alcotest.(check int) "import succeeds without --validate when annotation has id" 0 result;
  Lwt.return_unit

(* Test: annotation with existing id fails with --validate *)
let test_import_with_id_validate _switch () =
  let ws = make_temp_workspace "id-validate" in
  let _ =
    write_annotation_file ~annotations_dir:ws.annotations_dir
      ~container_id:"my-canvas" ~slug:"anno-with-id" ~contents:annotation_with_id
  in
  let result =
    run_miiify_import_validate ~annotations_dir:ws.annotations_dir ~git_repo:ws.git_repo
  in
  Alcotest.(check bool) "import fails with --validate when annotation has id" true (result <> 0);
  Lwt.return_unit

(* Test: compile with existing id is warned but accepted without --validate *)
let test_compile_with_id_no_validate _switch () =
  let ws = make_temp_workspace "compile-id-no-validate" in
  let _ =
    write_annotation_file ~annotations_dir:ws.annotations_dir
      ~container_id:"my-canvas" ~slug:"anno-with-id" ~contents:annotation_with_id
  in
  let import_result =
    run_miiify_import ~annotations_dir:ws.annotations_dir ~git_repo:ws.git_repo
  in
  Alcotest.(check int) "import succeeds" 0 import_result;
  let result = run_miiify_compile ~git_repo:ws.git_repo ~pack_repo:ws.pack_repo in
  Alcotest.(check int) "compile succeeds without --validate when annotation has id" 0 result;
  Lwt.return_unit

(* Test: compile with existing id fails with --validate *)
let test_compile_with_id_validate _switch () =
  let ws = make_temp_workspace "compile-id-validate" in
  let _ =
    write_annotation_file ~annotations_dir:ws.annotations_dir
      ~container_id:"my-canvas" ~slug:"anno-with-id" ~contents:annotation_with_id
  in
  let import_result =
    run_miiify_import ~annotations_dir:ws.annotations_dir ~git_repo:ws.git_repo
  in
  Alcotest.(check int) "import succeeds" 0 import_result;
  let result = run_miiify_compile_validate ~git_repo:ws.git_repo ~pack_repo:ws.pack_repo in
  Alcotest.(check bool) "compile fails with --validate when annotation has id" true (result <> 0);
  Lwt.return_unit

let () =
  Lwt_main.run @@
  run "Miiify Smoke Tests"
    [
      ("E2E", [ test_case "import+compile+http" `Quick test_import_compile_then_http ]);
      ( "ID handling",
        [
          test_case "import: id ignored without --validate" `Quick test_import_with_id_no_validate;
          test_case "import: id rejected with --validate" `Quick test_import_with_id_validate;
          test_case "compile: id ignored without --validate" `Quick test_compile_with_id_no_validate;
          test_case "compile: id rejected with --validate" `Quick test_compile_with_id_validate;
        ] );
    ]
