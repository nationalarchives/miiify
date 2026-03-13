(** Import JSON annotation files into Irmin Git store *)

open Lwt.Syntax
open Cmdliner
open Miiify

let import_annotation container_id path validate =
  let filename = Filename.basename path in
  
  (* Validate it's an annotation file (either *.json or extensionless) *)
  if not (Utils.Validation.is_valid_json_file filename) then
    let* () =
      Lwt_io.eprintlf
        "✗ %s/%s - invalid file (must be *.json or extensionless)" container_id
        filename
    in
    Lwt.fail (Failure "Invalid file")
  else
  
  (* Normalize filename -> slug (strip optional .json suffix) *)
  let slug =
    if String.ends_with ~suffix:".json" filename then
      String.sub filename 0 (String.length filename - 5)
    else
      filename
  in
  
  (* Validate slug is not empty after normalization *)
  if String.length slug = 0 then
    let* () =
      Lwt_io.eprintlf "✗ %s/%s - invalid filename (cannot be just '.json')"
        container_id filename
    in
    Lwt.fail (Failure "Invalid filename")
  else
  
  let* content_lines = Lwt_io.lines_of_file path |> Lwt_stream.to_list in
  let content = String.concat "\n" content_lines in
  
  (* Always validate basic JSON structure *)
  let* () = 
    match Utils.Validation.validate_basic_json content with
    | Ok () -> Lwt.return_unit
    | Error msg ->
        let* () = Lwt_io.printlf "✗ %s/%s - %s" container_id filename msg in
        Lwt.fail (Failure ("Invalid JSON in " ^ path))
  in
  
  (* Validate against schema if flag is set *)
  let* () = 
    if validate then
      match Utils.Validation.validate_annotation content with
      | Ok () -> 
          Lwt.return_unit
      | Error msg ->
          let* () =
            Lwt_io.eprintlf "✗ Validation failed: %s/%s - %s" container_id
              filename msg
          in
          let* () =
            Lwt_io.eprintl
              "  Hint: try again without --validate if you want to import arbitrary Web Annotation JSON."
          in
          Lwt.fail (Failure ("Validation failed for " ^ path))
    else
      Lwt.return_unit
  in

  (* Check for existing id - error if --validate, warn and continue otherwise *)
  let* () =
    try
      let json = Yojson.Basic.from_string content in
      match Yojson.Basic.Util.member "id" json with
      | `Null -> Lwt.return_unit
      | `String supplied_id ->
          if validate then
            let* () =
              Lwt_io.eprintlf "✗ %s/%s - annotation must not contain an id (%s)"
                container_id filename supplied_id
            in
            Lwt.fail (Failure ("Annotation contains existing id in " ^ path))
          else
            Lwt_io.printlf "ℹ %s/%s - Ignoring supplied ID (%s)"
              container_id filename supplied_id
      | _ -> Lwt.return_unit
    with Failure _ as e -> Lwt.fail e
       | _ -> Lwt.return_unit
  in
  
  (* Return key and data for batch commit *)
  let key = [container_id; slug] in
  Lwt.return (key, content)

let run_import ~input_dir ~git_path ~validate =
  let* () = Lwt_io.printl "Miiify Import" in
  let* () = Lwt_io.printlf "Input: %s" input_dir in
  let* () = Lwt_io.printlf "Git:   %s" git_path in

  let git_store = Storage_git.create ~fname:git_path in

  (* Check for annotations/ subdirectory (repo structure convention) *)
  let annotations_dir = Filename.concat input_dir "annotations" in
  let scan_dir =
    if Sys.file_exists annotations_dir && Sys.is_directory annotations_dir then
      annotations_dir
    else input_dir
  in

  (* Find all container directories *)
  let all_items = Sys.readdir scan_dir |> Array.to_list in

  (* Check for annotation files at root level (not allowed).
     - We always reject explicit *.json files.
     - For extensionless files (no '.'), only reject if they parse as JSON.
       This avoids breaking repos that have root docs like LICENSE.
  *)
  let root_candidates =
    all_items
    |> List.filter (fun f -> not (String.starts_with ~prefix:"." f))
    |> List.map (fun f -> (f, Filename.concat scan_dir f))
    |> List.filter (fun (_, path) -> not (Sys.is_directory path))
  in

  let root_json_files =
    root_candidates
    |> List.filter (fun (name, _) -> String.ends_with ~suffix:".json" name)
  in

  let root_extensionless =
    root_candidates
    |> List.filter (fun (name, _) -> not (String.contains name '.'))
  in

  let* root_extensionless_json_files =
    Lwt_list.filter_s
      (fun (_name, path) ->
        Lwt.catch
          (fun () ->
            let* content_lines = Lwt_io.lines_of_file path |> Lwt_stream.to_list in
            let content = String.concat "\n" content_lines in
            match Utils.Validation.validate_basic_json content with
            | Ok () -> Lwt.return true
            | Error _ -> Lwt.return false)
          (fun _exn -> Lwt.return false))
      root_extensionless
  in

  let* () =
    if List.length root_json_files > 0 || List.length root_extensionless_json_files > 0 then (
      let all_bad = root_json_files @ root_extensionless_json_files in
      let* () =
        Lwt_io.eprintlf
          "Error: Found %d annotation files at root level (must be inside container directories)"
          (List.length all_bad)
      in
      let* () =
        Lwt_list.iter_s
          (fun (name, _) -> Lwt_io.eprintlf "  - %s" name)
          all_bad
      in
      Lwt.fail
        (Failure
           "Invalid layout: annotations must be in <container>/<annotation> or <container>/<annotation>.json structure")
    ) else Lwt.return_unit
  in

  let containers =
    all_items
    |> List.filter (fun f -> not (String.starts_with ~prefix:"." f))
    |> List.map (fun name -> (name, Filename.concat scan_dir name))
    |> List.filter (fun (_, path) -> Sys.is_directory path)
    |> List.filter (fun (name, _) ->
           if not (Utils.Validation.is_valid_container_name name) then (
             Printf.fprintf stderr
               "Warning: Skipping invalid container name '%s' (use only a-z, A-Z, 0-9, -, _)\n%!"
               name;
             false
           ) else true)
  in

  (* Validate we have at least one container *)
  let* () =
    if List.length containers = 0 then (
      let* () = Lwt_io.eprintl "Error: No valid container directories found" in
      Lwt.fail (Failure "No containers to import")
    ) else Lwt.return_unit
  in

  (* Import files from each container *)
  let* total =
    Lwt_list.fold_left_s
      (fun count (container_id, container_path) ->
        let* () = Lwt_io.printlf "Processing %s..." container_id in
        let all_files = Sys.readdir container_path |> Array.to_list in

        (* Check for subdirectories (not allowed) *)
        let subdirs =
          all_files
          |> List.filter (fun f -> not (String.starts_with ~prefix:"." f))
          |> List.map (fun f -> (f, Filename.concat container_path f))
          |> List.filter (fun (_, path) -> Sys.is_directory path)
        in
        let* () =
          if List.length subdirs > 0 then (
            let* () =
              Lwt_io.eprintlf
                "Error: Container '%s' contains subdirectories (not allowed)"
                container_id
            in
            let* () =
              Lwt_list.iter_s
                (fun (name, _) -> Lwt_io.eprintlf "  - %s/" name)
                subdirs
            in
            Lwt.fail
              (Failure
                 "Invalid layout: containers must only contain annotation files (either *.json or extensionless), not subdirectories")
          ) else Lwt.return_unit
        in

        (* Filter to only annotation files (must be actual files) *)
        let json_files =
          all_files
          |> List.filter Utils.Validation.is_valid_json_file
          |> List.map (fun f -> (f, Filename.concat container_path f))
          |> List.filter (fun (_, path) -> not (Sys.is_directory path))
          |> List.map snd
        in

        (* Warn about non-annotation files *)
        let non_json_files =
          all_files
          |> List.filter (fun f ->
                 (not (String.starts_with ~prefix:"." f))
                 && not (Utils.Validation.is_valid_json_file f))
          |> List.map (fun f -> (f, Filename.concat container_path f))
          |> List.filter (fun (_, path) -> not (Sys.is_directory path))
        in
        let* () =
          if List.length non_json_files > 0 then
            Lwt_io.eprintlf "Warning: Skipping %d non-annotation files in %s/"
              (List.length non_json_files) container_id
          else Lwt.return_unit
        in

        (* Warn about empty containers *)
        let* () =
          if List.length json_files = 0 then
            Lwt_io.eprintlf "Warning: No annotation files found in %s/" container_id
          else Lwt.return_unit
        in

        (* Collect all annotations for batch commit *)
        let* items =
          Lwt_list.map_s
            (fun path -> import_annotation container_id path validate)
            json_files
        in

        (* Commit all annotations in one batch *)
        let* () =
          if List.length items > 0 then
            let message = Printf.sprintf "Import %s (%d annotations)" container_id (List.length items) in
            Storage_git.set_batch ~db:git_store ~items ~message
          else
            Lwt.return_unit
        in

        Lwt.return (count + List.length json_files))
      0 containers
  in

  let* () =
    if total = 0 then
      Lwt_io.eprintl
        "Warning: No annotations imported (no valid annotation files found)"
    else
      let container_word = if List.length containers = 1 then "container" else "containers" in
      Lwt_io.printlf "Imported %d annotations from %d %s" total
        (List.length containers) container_word
  in
  Lwt.return_unit

let import_directory input_dir git_path validate =
  (* Check if input directory exists before entering Lwt *)
  if not (Sys.file_exists input_dir) then (
    Printf.eprintf "Error: Input directory does not exist: %s\n" input_dir;
    exit 1
  );
  if not (Sys.is_directory input_dir) then (
    Printf.eprintf "Error: Path is not a directory: %s\n" input_dir;
    exit 1
  );
  
  let result =
    Lwt_main.run
      (Lwt.catch
         (fun () ->
           let* () = run_import ~input_dir ~git_path ~validate in
           Lwt.return (Ok ()))
         (fun exn -> Lwt.return (Error exn)))
  in
  match result with
  | Ok () -> ()
  | Error exn ->
      (* Avoid Cmdliner backtraces: errors are already printed near the source. *)
      (match exn with
      | Failure _ -> ()
      | _ ->
          Printf.eprintf "Error: %s\n" (Printexc.to_string exn));
      exit 1

let input_dir =
  let doc = "Input directory containing annotation files" in
  Arg.(value & opt string "./annotations" & info ["input"; "i"] ~docv:"DIR" ~doc)

let git_path =
  let doc = "Irmin Git store directory" in
  Arg.(value & opt string "git_store" & info ["git"; "g"] ~docv:"DIR" ~doc)

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
    `Pre "  miiify-import --input ./annotations --git ./git_store";
    `Pre "  miiify-import --input ./annotations --git ./git_store --validate";
  ] in
  let info = Cmd.info "import" ~version:"0.1.0" ~doc ~man in
  Cmd.v info Term.(const import_directory $ input_dir $ git_path $ validate_flag)

let () =
  exit (Cmd.eval cmd)
