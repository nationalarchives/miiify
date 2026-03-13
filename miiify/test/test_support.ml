let json_type_contains json expected =
  match Yojson.Basic.Util.member "type" json with
  | `String t -> String.equal t expected
  | `List ts ->
      List.exists
        (function
          | `String t -> String.equal t expected
          | _ -> false)
        ts
  | _ -> false

let assert_type_any json expected =
  Alcotest.(check bool)
    (Printf.sprintf "type contains one of: %s" (String.concat "," expected))
    true
    (List.exists (fun t -> json_type_contains json t) expected)

let assert_type json expected =
  Alcotest.(check bool)
    (Printf.sprintf "type contains %s" expected)
    true
    (json_type_contains json expected)

let string_contains haystack needle =
  let hlen = String.length haystack in
  let nlen = String.length needle in
  if nlen = 0 then true
  else
    let rec loop i =
      if i + nlen > hlen then false
      else if String.sub haystack i nlen = needle then true
      else loop (i + 1)
    in
    loop 0

(* Sample annotation data matching README examples *)
let highlight_annotation =
  {|{
  "type": "Annotation",
  "motivation": "highlighting",
  "body": {
    "type": "TextualBody",
    "value": "Important passage",
    "purpose": "commenting"
  },
  "target": "https://example.com/iiif/canvas/1#xywh=100,100,200,50"
}|}

let highlight_target = "https://example.com/iiif/canvas/1#xywh=100,100,200,50"

let comment_annotation =
  {|{
  "type": "Annotation",
  "motivation": "commenting",
  "body": {
    "type": "TextualBody",
    "value": "This is a fascinating detail",
    "purpose": "commenting"
  },
  "target": "https://example.com/iiif/canvas/1#xywh=300,150,100,75"
}|}

let comment_target = "https://example.com/iiif/canvas/1#xywh=300,150,100,75"

let annotation_with_id =
  {|{
  "id": "https://example.com/existing-id",
  "type": "Annotation",
  "motivation": "highlighting",
  "body": {
    "type": "TextualBody",
    "value": "Has an existing id",
    "purpose": "commenting"
  },
  "target": "https://example.com/iiif/canvas/1#xywh=100,100,200,50"
}|}

let write_file path contents =
  let oc = open_out path in
  output_string oc contents;
  close_out oc

let workspace_root () =
  let cwd = Sys.getcwd () in
  if String.ends_with ~suffix:"_build/default/test" cwd then
    Filename.dirname (Filename.dirname (Filename.dirname cwd))
  else cwd

let build_root () =
  (* When run under dune, Sys.executable_name typically looks like:
     .../_build/default/test/<name>.exe
     We want .../_build/default
  *)
  let exe = Sys.executable_name in
  let test_dir = Filename.dirname exe in
  Filename.dirname test_dir

let import_exe () = Filename.concat (build_root ()) "bin/import.exe"

let compile_exe () = Filename.concat (build_root ()) "bin/compile.exe"

type temp_workspace = {
  temp_dir : string;
  annotations_dir : string;
  git_repo : string;
  pack_repo : string;
}

let make_temp_workspace test_name =
  let ts = int_of_float (Unix.time ()) in
  let pid = Unix.getpid () in
  let temp_dir = Printf.sprintf "/tmp/miiify_test_%s_%d_%d" test_name pid ts in
  let annotations_dir = temp_dir ^ "/annotations" in
  let git_repo = temp_dir ^ "/git_store" in
  let pack_repo = temp_dir ^ "/pack_store" in

  Unix.mkdir temp_dir 0o755;
  Unix.mkdir annotations_dir 0o755;
  { temp_dir; annotations_dir; git_repo; pack_repo }

let write_annotation_file ~annotations_dir ~container_id ~slug ~contents =
  let container_dir = Filename.concat annotations_dir container_id in
  if not (Sys.file_exists container_dir) then Unix.mkdir container_dir 0o755;
  let path = Filename.concat container_dir (slug ^ ".json") in
  write_file path contents;
  path

let run_miiify_import ~annotations_dir ~git_repo =
  let cmd =
    Printf.sprintf "%s --input %s --git %s > /dev/null 2>&1"
      (Filename.quote (import_exe ())) (Filename.quote annotations_dir)
      (Filename.quote git_repo)
  in
  Sys.command cmd

let run_miiify_import_validate ~annotations_dir ~git_repo =
  let cmd =
    Printf.sprintf "%s --input %s --git %s --validate > /dev/null 2>&1"
      (Filename.quote (import_exe ())) (Filename.quote annotations_dir)
      (Filename.quote git_repo)
  in
  Sys.command cmd

let run_miiify_compile ~git_repo ~pack_repo =
  let cmd =
    Printf.sprintf "%s --git %s --pack %s > /dev/null 2>&1"
      (Filename.quote (compile_exe ())) (Filename.quote git_repo)
      (Filename.quote pack_repo)
  in
  Sys.command cmd

let run_miiify_compile_validate ~git_repo ~pack_repo =
  let cmd =
    Printf.sprintf "%s --git %s --pack %s --validate > /dev/null 2>&1"
      (Filename.quote (compile_exe ())) (Filename.quote git_repo)
      (Filename.quote pack_repo)
  in
  Sys.command cmd

let create_test_db_from_files test_name =
  let ws = make_temp_workspace test_name in

  let _ =
    write_annotation_file ~annotations_dir:ws.annotations_dir
      ~container_id:"my-canvas" ~slug:"highlight-1" ~contents:highlight_annotation
  in
  let _ =
    write_annotation_file ~annotations_dir:ws.annotations_dir
      ~container_id:"my-canvas" ~slug:"comment-1" ~contents:comment_annotation
  in

  let import_result =
    run_miiify_import ~annotations_dir:ws.annotations_dir ~git_repo:ws.git_repo
  in
  if import_result <> 0 then
    Lwt.fail_with (Printf.sprintf "Import failed with code %d" import_result)
  else
    let compile_result =
      run_miiify_compile ~git_repo:ws.git_repo ~pack_repo:ws.pack_repo
    in
    if compile_result <> 0 then
      Lwt.fail_with (Printf.sprintf "Compile failed with code %d" compile_result)
    else Miiify.Model.create ~repository_name:ws.pack_repo

let create_test_db_pack test_name =
  let repository_name =
    Printf.sprintf "test_pack_%s_%f" test_name (Unix.time ())
  in
  Miiify.Model.create ~repository_name
