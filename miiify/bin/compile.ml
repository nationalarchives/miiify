(** Compile Git store to optimized Pack store *)

open Lwt.Syntax
open Cmdliner
open Miiify

module Git_store = Storage_git.Store
module Pack_store = Storage_pack.Store

let is_annotation_filename filename =
  Utils.Validation.is_valid_json_file filename

let normalize_slug filename =
  if String.ends_with ~suffix:".json" filename then
    String.sub filename 0 (String.length filename - 5)
  else
    filename

let process_annotation git_path data validate =
  let leaf_name = List.nth git_path (List.length git_path - 1) in
  
  (* Only treat valid annotation filenames as annotations; ignore everything else. *)
  if not (is_annotation_filename leaf_name) then (
    let* () =
      Lwt_io.eprintlf "Warning: Skipping non-annotation file: %s"
        (String.concat "/" git_path)
    in
    Lwt.return_none
  ) else
  let slug_norm = normalize_slug leaf_name in
  if String.length slug_norm = 0 then (
    let* () =
      Lwt_io.eprintlf
        "✗ Invalid annotation filename (cannot be just '.json'): %s"
        (String.concat "/" git_path)
    in
    Lwt.fail (Failure "Invalid annotation filename")
  ) else
  
  (* Transform flat Git structure to hierarchical Pack structure:
     Git: [container; slug]
     Pack: [container; "collection"; slug] *)
  let pack_path_opt =
    match git_path with
    | [ container; _slug ] -> Some [ container; "collection"; slug_norm ]
    | _ -> None
  in
  let* pack_path =
    match pack_path_opt with
    | Some pack_path -> Lwt.return pack_path
    | None ->
        let* () =
          Lwt_io.eprintlf "✗ Unexpected Git path structure: %s"
            (String.concat "/" git_path)
        in
        Lwt.fail (Failure "Unexpected path structure")
  in
  
  (* Always validate basic JSON *)
  let* () = 
    match Utils.Validation.validate_basic_json data with
    | Ok () -> Lwt.return_unit
    | Error msg ->
        let* () = Lwt_io.printlf "✗ %s: %s" (String.concat "/" git_path) msg in
        Lwt.fail (Failure ("JSON validation failed for " ^ String.concat "/" git_path))
  in

  (* Check if user supplied an ID - warn that it will be ignored *)
  let* () =
    try
      let json = Yojson.Basic.from_string data in
      match Yojson.Basic.Util.member "id" json with
      | `Null -> Lwt.return_unit
      | `String supplied_id ->
          Lwt_io.printlf "ℹ %s - Ignoring supplied ID (%s)"
            (String.concat "/" git_path) supplied_id
      | _ -> Lwt.return_unit
    with _ -> Lwt.return_unit
  in
  
  (* Validate against schema if flag is set *)
  let* () = 
    if validate then
      match Utils.Validation.validate_annotation data with
      | Ok () -> 
          Lwt.return_unit
      | Error msg ->
          let* () =
            Lwt_io.eprintlf "✗ Schema validation failed for %s: %s"
              (String.concat "/" git_path) msg
          in
          let* () =
            Lwt_io.eprintl
              "  Hint: try again without --validate if you want to compile arbitrary Web Annotation JSON."
          in
          Lwt.fail (Failure ("Schema validation failed for " ^ String.concat "/" git_path))
    else
      Lwt.return_unit
  in
  
  Lwt.return_some (pack_path, data)

let rec collect_annotations git_store path validate =
  let* git_tree = Git_store.get_tree git_store path in
  let* entries = Git_store.Tree.list git_tree [] in
  
  Lwt_list.fold_left_s (fun acc (name, _tree) ->
    let step_name = Irmin.Type.to_string Git_store.Path.step_t name in
    let git_path = path @ [step_name] in
    
    (* Check if it's a contents or node by trying to get it *)
    let* is_contents = 
      Lwt.catch
        (fun () -> let* _ = Git_store.get git_store git_path in Lwt.return true)
        (fun _ -> Lwt.return false)
    in
    
    if is_contents then
      let* data = Git_store.get git_store git_path in
      let* result = process_annotation git_path data validate in
      match result with
      | Some item -> Lwt.return (item :: acc)
      | None -> Lwt.return acc
    else
      let* subitems = collect_annotations git_store git_path validate in
      Lwt.return (subitems @ acc)
  ) [] entries

let run_compile ~git_path ~pack_path ~validate =
  let* () = Lwt_io.printl "Miiify Compile" in
  let* () = Lwt_io.printlf "Source: Git (%s)" git_path in
  let* () = Lwt_io.printlf "Target: Pack (%s)" pack_path in

  (* Initialize Git store *)
  let git_config = Irmin_git.config ~bare:true git_path in
  let* git_repo = Git_store.Repo.v git_config in
  let* git_store = Git_store.main git_repo in

  (* Initialize fresh Pack store *)
  let pack_config = Storage_pack.Repo_config.config ~fresh:true pack_path in
  let* pack_repo = Pack_store.Repo.v pack_config in
  let* pack_store = Pack_store.main pack_repo in

  (* Get list of containers (top-level directories) *)
  let* root_tree = Git_store.get_tree git_store [] in
  let* root_entries = Git_store.Tree.list root_tree [] in

  (* Keep only directory entries with valid container names; ignore root files (README, LICENSE, etc). *)
  let* containers =
    Lwt_list.filter_map_s
      (fun (container_step, _tree) ->
        let container =
          Irmin.Type.to_string Git_store.Path.step_t container_step
        in
        let* is_contents =
          Lwt.catch
            (fun () ->
              let* _ = Git_store.get git_store [ container ] in
              Lwt.return true)
            (fun _ -> Lwt.return false)
        in
        if is_contents then (
          let* () =
            Lwt_io.eprintlf "Warning: Skipping root file (not a container): %s"
              container
          in
          Lwt.return_none
        ) else if not (Utils.Validation.is_valid_container_name container) then (
          let* () =
            Lwt_io.eprintlf
              "Warning: Skipping invalid container name '%s' (use only a-z, A-Z, 0-9, -, _)"
              container
          in
          Lwt.return_none
        ) else
          Lwt.return_some (container_step, _tree))
      root_entries
  in

  (* For each container, create metadata and copy annotations *)
  let* total =
    Lwt_list.fold_left_s
      (fun count (container_step, _) ->
        let container =
          Irmin.Type.to_string Git_store.Path.step_t container_step
        in
        let* () = Lwt_io.printlf "Processing %s..." container in

        (* Collect all annotations from Git for this container *)
        let* items = collect_annotations git_store [ container ] validate in

        (* Create container metadata *)
        let now = Ptime_clock.now () in
        let timestamp = Ptime.to_rfc3339 now in
        let container_json =
          Printf.sprintf
            {|{"type":"AnnotationCollection","label":"%s","created":"%s"}|}
            container timestamp
        in
        let metadata_item = ([ container; "metadata" ], container_json) in

        (* Batch commit: metadata + all annotations in one transaction *)
        let all_items = metadata_item :: items in
        let* () =
          if List.length all_items > 0 then
            let message = Printf.sprintf "Compile %s (%d annotations)" container (List.length items) in
            Storage_pack.set_batch ~db:(Lwt.return pack_store) ~items:all_items ~message
          else
            Lwt.return_unit
        in

        Lwt.return (count + List.length items + 1))
      0 containers
  in

  (* Close repositories *)
  let* () = Git_store.Repo.close git_repo in
  let* () = Pack_store.Repo.close pack_repo in

  let num_containers = List.length containers in
  let num_annotations = total - num_containers in
  let container_word = if num_containers = 1 then "container" else "containers" in
  let* () = Lwt_io.printlf "Compiled %d annotations from %d %s" num_annotations num_containers container_word in
  Lwt.return_unit

let compile_stores git_path pack_path validate =
  let result =
    Lwt_main.run
      (Lwt.catch
         (fun () ->
           let* () = run_compile ~git_path ~pack_path ~validate in
           Lwt.return (Ok ()))
         (fun exn -> Lwt.return (Error exn)))
  in
  match result with
  | Ok () -> ()
  | Error exn ->
      (match exn with
      | Failure _ -> ()
      | _ -> Printf.eprintf "Error: %s\n" (Printexc.to_string exn));
      exit 1

let git_path =
  let doc = "Source Git store directory" in
  Arg.(value & opt string "db" & info ["git"; "g"] ~docv:"DIR" ~doc)

let pack_path =
  let doc = "Destination Pack store directory" in
  Arg.(value & opt string "db-pack" & info ["pack"; "p"] ~docv:"DIR" ~doc)

let validate_flag =
  let doc = "Enable strict schema validation against specification.atd (structure and JSON syntax always validated)" in
  Arg.(value & flag & info ["validate"; "v"] ~doc)

let cmd =
  let doc = "Compile Git store into optimized Pack store" in
  let man = [
    `S Manpage.s_description;
    `P "Compiles a Git-based miiify store into an optimized Pack store for production.";
    `P "The Git store is useful for development and version control, while Pack provides better runtime performance.";
    `P "Always validates: path structure and JSON syntax.";
    `P "With --validate: also validates annotations against W3C schema.";
    `P "Example:";
    `Pre "  miiify-compile";
    `Pre "  miiify-compile --git ./db --pack ./db-pack";
    `Pre "  miiify-compile --git ./db --pack ./db-pack --validate";
  ] in
  let info = Cmd.info "compile" ~version:"0.1.0" ~doc ~man in
  Cmd.v info Term.(const compile_stores $ git_path $ pack_path $ validate_flag)

let () =
  exit (Cmd.eval cmd)
