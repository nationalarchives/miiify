(** Import JSON annotation files into Irmin Git store *)

open Lwt.Syntax
open Cmdliner
open Miiify

let import_annotation git_store container_id path validate =
  let filename = Filename.basename path in
  
  (* Validate it's a JSON file *)
  if not (Utils.Validation.is_valid_json_file filename) then
    let* () =
      Lwt_io.eprintlf "✗ %s/%s - invalid file (must be *.json)" container_id
        filename
    in
    Lwt.fail (Failure "Invalid file")
  else
  
  (* Strip .json extension to create slug *)
  let slug = String.sub filename 0 (String.length filename - 5) in
  
  (* Validate slug is not empty after stripping *)
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

  (* Enforce ID management rule: user-supplied IDs are not allowed. *)
  let* () =
    match Utils.Validation.reject_top_level_id content with
    | Ok () -> Lwt.return_unit
    | Error _ ->
        let* () =
          Lwt_io.eprintlf
            "✗ %s/%s supplies an 'id' field. Remove it; Miiify derives 'id' from --base-url and the file path."
            container_id filename
        in
        Lwt.fail (Failure ("Invalid annotation: " ^ path))
  in
  
  (* Store in flat structure: container/slug *)
  let key = [container_id; slug] in
  let message = Printf.sprintf "Import %s/%s" container_id filename in
  
  let* () = Storage_git.set ~db:git_store ~key ~data:content ~message in
  Lwt_io.printlf "  %s/%s" container_id filename

let run_import ~input_dir ~git_path ~validate =
  let* () = Lwt_io.printl "Miiify Import" in
  let* () = Lwt_io.printlf "Input: %s" input_dir in
  let* () = Lwt_io.printlf "Git:   %s" git_path in
  let* () = Lwt_io.printl "" in

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

  (* Check for JSON files at root level (not allowed) *)
  let root_files =
    all_items
    |> List.filter (fun f -> not (String.starts_with ~prefix:"." f))
    |> List.map (fun f -> (f, Filename.concat scan_dir f))
    |> List.filter (fun (_, path) -> not (Sys.is_directory path))
    |> List.filter (fun (name, _) -> String.ends_with ~suffix:".json" name)
  in
  let* () =
    if List.length root_files > 0 then (
      let* () =
        Lwt_io.eprintlf
          "Error: Found %d .json files at root level (must be inside container directories)"
          (List.length root_files)
      in
      let* () =
        Lwt_list.iter_s
          (fun (name, _) -> Lwt_io.eprintlf "  - %s" name)
          root_files
      in
      Lwt.fail
        (Failure
           "Invalid layout: annotations must be in <container>/<annotation>.json structure")
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
                 "Invalid layout: containers must only contain .json files, not subdirectories")
          ) else Lwt.return_unit
        in

        (* Filter to only .json files (must be actual files) *)
        let json_files =
          all_files
          |> List.filter Utils.Validation.is_valid_json_file
          |> List.map (fun f -> (f, Filename.concat container_path f))
          |> List.filter (fun (_, path) -> not (Sys.is_directory path))
          |> List.map snd
        in

        (* Warn about non-JSON files *)
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
            Lwt_io.eprintlf "Warning: Skipping %d non-JSON files in %s/"
              (List.length non_json_files) container_id
          else Lwt.return_unit
        in

        (* Warn about empty containers *)
        let* () =
          if List.length json_files = 0 then
            Lwt_io.eprintlf "Warning: No JSON files found in %s/" container_id
          else Lwt.return_unit
        in

        (* Import annotation files *)
        let* () =
          Lwt_list.iter_s
            (fun path -> import_annotation git_store container_id path validate)
            json_files
        in

        Lwt.return (count + List.length json_files))
      0 containers
  in

  let* () = Lwt_io.printl "" in
  let* () =
    if total = 0 then
      Lwt_io.eprintl "Warning: No annotations imported (no valid .json files found)"
    else
      Lwt_io.printlf "Imported %d annotations from %d containers" total
        (List.length containers)
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
