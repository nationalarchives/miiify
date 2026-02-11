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
    let current_path = path @ [step_name] in
    
    (* Check if it's a contents or node by trying to get it *)
    let* is_contents = 
      Lwt.catch
        (fun () -> let* _ = Git_store.get git_store current_path in Lwt.return true)
        (fun _ -> Lwt.return false)
    in
    
    if is_contents then
      let* data = Git_store.get git_store current_path in
      
      (* Always validate path structure *)
      let* () = 
        match Utils.Validation.validate_path current_path with
        | Ok () -> Lwt.return_unit
        | Error msg ->
            let* () = Lwt_io.printlf "✗ Invalid structure: %s" msg in
            Lwt.fail (Failure ("Structure validation failed: " ^ msg))
      in
      
      (* Always validate basic JSON *)
      let* () = 
        match Utils.Validation.validate_basic_json data with
        | Ok () -> Lwt.return_unit
        | Error msg ->
            let* () = Lwt_io.printlf "✗ %s: %s" (String.concat "/" current_path) msg in
            Lwt.fail (Failure ("JSON validation failed for " ^ String.concat "/" current_path))
      in
      
      (* Validate against schema if flag is set and path is an annotation *)
      let* () = 
        if validate && List.mem "collection" current_path then
          match Utils.Validation.validate_annotation data with
          | Ok () -> 
              Lwt.return_unit
          | Error msg ->
              let* () = Lwt_io.printlf "✗ Schema validation failed for %s: %s" (String.concat "/" current_path) msg in
              Lwt.fail (Failure ("Schema validation failed for " ^ String.concat "/" current_path))
        else
          Lwt.return_unit
      in
      
      let message = Printf.sprintf "Compile: %s" (String.concat "/" current_path) in
      let* () = Pack_store.set_exn pack_store current_path data 
        ~info:(Storage_pack.info message)
      in
      Lwt.return (count + 1)
    else
      let* subcount = copy_tree git_store pack_store current_path validate in
      Lwt.return (count + subcount)
  ) 0 entries

let compile_stores git_path pack_path validate =
  Lwt_main.run (
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
    
    (* Copy all entries and count them *)
    let* total = copy_tree git_store pack_store [] validate in
    
    (* Close repositories *)
    let* () = Git_store.Repo.close git_repo in
    let* () = Pack_store.Repo.close pack_repo in
    
    let* () = Lwt_io.printl "" in
    Lwt_io.printlf "Compiled %d items to Pack store" total
  )

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
