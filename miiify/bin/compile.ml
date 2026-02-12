(** Compile Git store to optimized Pack store *)

open Lwt.Syntax
open Cmdliner
open Miiify

module Git_store = Storage_git.Store
module Pack_store = Storage_pack.Store

let rec copy_tree git_store pack_store path validate =
  let* git_tree = Git_store.get_tree git_store path in
  let* entries = Git_store.Tree.list git_tree [] in
  
  Lwt_list.fold_left_s (fun count (name, _tree) ->
    let step_name = Irmin.Type.to_string Git_store.Path.step_t name in
    let git_path = path @ [step_name] in
    
    (* Check if it's a contents or node by trying to get it *)
    let* is_contents = 
      Lwt.catch
        (fun () -> let* _ = Git_store.get git_store git_path in Lwt.return true)
        (fun _ -> Lwt.return false)
    in
    
    let is_annotation_filename filename =
      Utils.Validation.is_valid_json_file filename
    in

    let normalize_slug filename =
      if String.ends_with ~suffix:".json" filename then
        String.sub filename 0 (String.length filename - 5)
      else
        filename
    in

    if is_contents then
      let* data = Git_store.get git_store git_path in

      (* Only treat valid annotation filenames as annotations; ignore everything else. *)
      let leaf_name = step_name in
      if not (is_annotation_filename leaf_name) then (
        let* () =
          Lwt_io.eprintlf "Warning: Skipping non-annotation file: %s"
            (String.concat "/" git_path)
        in
        Lwt.return count
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

      (* Enforce ID management rule: user-supplied IDs are not allowed. *)
      let* () =
        match Utils.Validation.reject_top_level_id data with
        | Ok () -> Lwt.return_unit
        | Error _ ->
            let* () =
              Lwt_io.printlf
                "✗ %s supplies an 'id' field. Remove it; Miiify derives 'id' from --base-url and the file path."
                (String.concat "/" git_path)
            in
            Lwt.fail
              (Failure
                 ("ID validation failed for " ^ String.concat "/" git_path))
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
      
      let message = Printf.sprintf "Compile: %s" (String.concat "/" pack_path) in
      let* () = Pack_store.set_exn pack_store pack_path data 
        ~info:(Storage_pack.info message)
      in
      Lwt.return (count + 1)
    else
      let* subcount = copy_tree git_store pack_store git_path validate in
      Lwt.return (count + subcount)
  ) 0 entries

let run_compile ~git_path ~pack_path ~validate =
  let* () = Lwt_io.printl "Miiify Compile" in
  let* () = Lwt_io.printlf "Source: Git (%s)" git_path in
  let* () = Lwt_io.printlf "Target: Pack (%s)" pack_path in
  let* () = Lwt_io.printl "" in

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

        (* Create container metadata in Pack *)
        let now = Ptime_clock.now () in
        let timestamp = Ptime.to_rfc3339 now in
        let container_json =
          Printf.sprintf
            {|{"type":"AnnotationContainer","label":"%s","created":"%s"}|}
            container timestamp
        in
        let* () =
          Pack_store.set_exn pack_store [ container; "metadata" ] container_json
            ~info:
              (Storage_pack.info (Printf.sprintf "Create container %s" container))
        in

        (* Copy annotations from Git to Pack with transformation *)
        let* subcount = copy_tree git_store pack_store [ container ] validate in
        Lwt.return (count + subcount + 1))
      0 containers
  in

  (* Close repositories *)
  let* () = Git_store.Repo.close git_repo in
  let* () = Pack_store.Repo.close pack_repo in

  let* () = Lwt_io.printl "" in
  let* () = Lwt_io.printlf "Compiled %d items to Pack store" total in
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
