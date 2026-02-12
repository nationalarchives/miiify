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

let write_file path contents =
  let oc = open_out path in
  output_string oc contents;
  close_out oc

let workspace_root () =
  let cwd = Sys.getcwd () in
  if String.ends_with ~suffix:"_build/default/test" cwd then
    Filename.dirname (Filename.dirname (Filename.dirname cwd))
  else cwd

let create_test_db_from_files test_name =
  let timestamp = Unix.time () |> string_of_float in
  let temp_dir = Printf.sprintf "/tmp/miiify_test_%s_%s" test_name timestamp in
  let annotations_dir = temp_dir ^ "/annotations" in
  let git_repo = temp_dir ^ "/db-git" in
  let pack_repo = temp_dir ^ "/db-pack" in

  Unix.mkdir temp_dir 0o755;
  Unix.mkdir annotations_dir 0o755;
  Unix.mkdir (annotations_dir ^ "/my-canvas") 0o755;

  write_file (annotations_dir ^ "/my-canvas/highlight-1.json") highlight_annotation;
  write_file (annotations_dir ^ "/my-canvas/comment-1.json") comment_annotation;

  let root = workspace_root () in

  let import_cmd =
    Printf.sprintf
      "cd %s && dune exec miiify-import -- --input %s --git %s > /dev/null 2>&1"
      (Filename.quote root) (Filename.quote annotations_dir)
      (Filename.quote git_repo)
  in
  let import_result = Sys.command import_cmd in
  if import_result <> 0 then
    Lwt.fail_with (Printf.sprintf "Import failed with code %d" import_result)
  else
    let compile_cmd =
      Printf.sprintf
        "cd %s && dune exec miiify-compile -- --git %s --pack %s > /dev/null 2>&1"
        (Filename.quote root) (Filename.quote git_repo) (Filename.quote pack_repo)
    in
    let compile_result = Sys.command compile_cmd in
    if compile_result <> 0 then
      Lwt.fail_with (Printf.sprintf "Compile failed with code %d" compile_result)
    else Miiify.Model.create ~repository_name:pack_repo

let create_test_db_pack test_name =
  let repository_name =
    Printf.sprintf "test_pack_%s_%f" test_name (Unix.time ())
  in
  Miiify.Model.create ~repository_name
