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

let import_annotation git_store container_id path validate =
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
  
  (* Validate if flag is set *)
  let* () = 
    if validate then
      match validate_annotation content with
      | Ok () -> 
          Lwt.return_unit
      | Error msg ->
          let* () = Lwt_io.printlf "✗ Validation failed: %s/%s - %s" container_id filename msg in
          Lwt.fail (Failure ("Validation failed for " ^ path))
    else
      Lwt.return_unit
  in
  
  (* Store in container/collection/slug structure *)
  let key = [container_id; "collection"; slug] in
  let message = Printf.sprintf "Import %s/%s" container_id filename in
  
  let* () = Storage_git.set ~db:git_store ~key ~data:content ~message in
  Lwt_io.printlf "  %s/%s" container_id filename

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
  
  Lwt_main.run (
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
      else
        input_dir
    in
    
    (* Find all container directories *)
    let containers = Sys.readdir scan_dir 
                     |> Array.to_list
                     |> List.filter (fun f -> 
                         not (String.starts_with ~prefix:"." f))
                     |> List.map (fun name -> (name, Filename.concat scan_dir name))
                     |> List.filter (fun (_, path) -> Sys.is_directory path)
    in
    
    (* Import files from each container *)
    let* total = Lwt_list.fold_left_s (fun count (container_id, container_path) ->
      let files = Sys.readdir container_path
                  |> Array.to_list
                  |> List.filter (fun f -> not (String.starts_with ~prefix:"." f))
                  |> List.map (Filename.concat container_path)
                  |> List.filter (fun p -> not (Sys.is_directory p))
      in
      
      (* Create container metadata if it doesn't exist *)
      let* container_exists = Storage_git.exists ~db:git_store ~key:[container_id; "main"] in
      let* () = 
        if not container_exists then
          let now = Ptime_clock.now () in
          let timestamp = Ptime.to_rfc3339 now in
          let container_json = Printf.sprintf {|{"type":"AnnotationContainer","label":"%s","created":"%s"}|} container_id timestamp in
          let message = Printf.sprintf "Create container %s" container_id in
          Storage_git.set ~db:git_store ~key:[container_id; "main"] ~data:container_json ~message
        else
          Lwt.return_unit
      in
      
      let* () = Lwt_list.iter_s (fun path ->
        import_annotation git_store container_id path validate
      ) files in
      
      Lwt.return (count + List.length files)
    ) 0 containers in
    
    let* () = Lwt_io.printl "" in
    Lwt_io.printlf "Imported %d annotations from %d containers" total (List.length containers)
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
