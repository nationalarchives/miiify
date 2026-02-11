(** Import JSON annotation files into Irmin Git store *)

open Lwt.Syntax
open Cmdliner
open Miiify

let validate_annotation content =
  try
    let _ = Specification_j.specification_of_string content in
    Ok ()
  with
  | Yojson.Json_error msg -> Error ("JSON parse error: " ^ msg)
  | Atdgen_runtime.Oj_run.Error msg -> Error ("Schema validation error: " ^ msg)
  | e -> Error ("Validation error: " ^ Printexc.to_string e)

let import_annotation git_store path validate =
  let filename = Filename.basename path in
  (* Strip .json extension to create slug *)
  let slug = 
    if String.length filename > 5 && String.ends_with ~suffix:".json" filename then
      String.sub filename 0 (String.length filename - 5)
    else
      filename
  in
  
  let* content_lines = Lwt_io.lines_of_file path |> Lwt_stream.to_list in
  let content = String.concat "\n" content_lines in
  
  let* () = Lwt_io.printlf "Importing %s -> %s (%d lines)" filename slug (List.length content_lines) in
  
  (* Validate if flag is set *)
  let* () = 
    if validate then
      match validate_annotation content with
      | Ok () -> 
          let* () = Lwt_io.printl "  ✓ Validation passed" in
          Lwt.return_unit
      | Error msg ->
          let* () = Lwt_io.printlf "  ✗ Validation failed: %s" msg in
          Lwt.fail (Failure ("Validation failed for " ^ path))
    else
      Lwt.return_unit
  in
  
  (* Store in annotations/<slug> (without .json extension) *)
  let key = ["annotations"; slug] in
  let message = Printf.sprintf "Import %s" filename in
  
  let* () = Storage_git.set ~db:git_store ~key ~data:content ~message in
  Lwt_io.printlf "✓ Imported %s" slug

let import_directory input_dir git_path validate =
  Lwt_main.run (
    let* () = Lwt_io.printl "Miiify Import" in
    let* () = Lwt_io.printlf "Input: %s" input_dir in
    let* () = Lwt_io.printlf "Git:   %s" git_path in
    let* () = Lwt_io.printlf "Validate: %b" validate in
    let* () = Lwt_io.printl "" in
    
    let git_store = Storage_git.create ~fname:git_path in
    
    (* Check for annotations/ subdirectory (repo structure convention) *)
    let annotations_dir = Filename.concat input_dir "annotations" in
    let scan_dir = 
      if Sys.file_exists annotations_dir && Sys.is_directory annotations_dir then
        annotations_dir
      else
        input_dir
    in
    
    let* () = 
      if scan_dir = annotations_dir then
        Lwt_io.printl "Using annotations/ subdirectory"
      else
        Lwt.return_unit
    in
    
    (* Find all files in source directory *)
    let files = Sys.readdir scan_dir 
                |> Array.to_list
                |> List.filter (fun f -> 
                    not (String.starts_with ~prefix:"." f))
                |> List.map (Filename.concat scan_dir)
                |> List.filter (fun p -> not (Sys.is_directory p))
    in
    
    let* () = Lwt_io.printlf "Found %d annotation files" (List.length files) in
    let* () = Lwt_io.printl "" in
    
    (* Import each file *)
    let* () = Lwt_list.iter_s (fun path ->
      import_annotation git_store path validate
    ) files in
    
    let* () = Lwt_io.printl "" in
    Lwt_io.printl "Import complete!"
  )

let input_dir =
  let doc = "Input directory containing annotation files" in
  Arg.(value & opt string "./annotations" & info ["input"; "i"] ~docv:"DIR" ~doc)

let git_path =
  let doc = "Irmin Git store directory" in
  Arg.(value & opt string "db" & info ["git"; "g"] ~docv:"DIR" ~doc)

let validate_flag =
  let doc = "Validate JSON against specification.atd schema before importing" in
  Arg.(value & flag & info ["validate"; "v"] ~doc)

let cmd =
  let doc = "Import JSON annotation files into Irmin Git store (development tool)" in
  let man = [
    `S Manpage.s_description;
    `P "Imports JSON annotation files into Irmin Git store for development/testing.";
    `P "In production, use 'miiify clone' to clone a remote repository instead.";
    `P "Example:";
    `Pre "  miiify-import --input ./annotations --git ./db";
    `Pre "  miiify-import --input ./annotations --git ./db --validate";
  ] in
  let info = Cmd.info "import" ~version:"0.1.0" ~doc ~man in
  Cmd.v info Term.(const import_directory $ input_dir $ git_path $ validate_flag)

let () =
  exit (Cmd.eval cmd)
