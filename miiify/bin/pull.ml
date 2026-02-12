(** Pull updates from remote and merge into Irmin Git *)

open Lwt.Syntax
open Cmdliner

module Store = Irmin_git_unix.FS.KV(Irmin.Contents.String)
module Sync = Irmin.Sync.Make(Store)

let pull_updates git_path remote_url branch =
  Lwt_main.run (
    let* () = Lwt_io.printl "Miiify Pull" in
    let* () = Lwt_io.printlf "Store:  %s" git_path in
    let* () = Lwt_io.printlf "Remote: %s" remote_url in
    let* () = Lwt_io.printlf "Branch: %s" branch in
    let* () = Lwt_io.printl "" in
    
    Lwt.catch (fun () ->
      let* () = Lwt_io.printl "Opening Git store..." in
      let config = Irmin_git.config ~bare:true git_path in
      let* repo = Store.Repo.v config in
      let* store = Store.main repo in
      
      let* () = Lwt_io.printl "Pulling from remote..." in
      let* remote_ref = Store.remote remote_url in
      
      (* Pull from remote - fetches and merges into current branch *)
      let* result = Sync.pull store remote_ref `Set in
      
      match result with
      | Ok (`Head _) ->
          let* () = Lwt_io.printl "Successfully pulled updates" in
          let* () = Lwt_io.printlf "Git store updated at: %s" git_path in
          Lwt.return_unit
      | Ok `Empty ->
          let* () = Lwt_io.printl "No updates (remote is empty)" in
          Lwt.return_unit
      | Error (`Msg msg) ->
          let* () = Lwt_io.printlf "Pull failed: %s" msg in
          Lwt.fail_with msg
      | Error (`Conflict msg) ->
          let* () = Lwt_io.printlf "Conflict during pull: %s" msg in
          let* () = Lwt_io.printl "Manual resolution required" in
          Lwt.fail_with msg
    ) (fun exn ->
      let error_msg = Printexc.to_string exn in
      
      (* Detect network/connectivity errors *)
      let is_network_error = 
        String.lowercase_ascii error_msg |> fun msg ->
        List.exists (fun pattern -> 
          try Str.search_forward (Str.regexp_case_fold pattern) msg 0 >= 0 
          with Not_found -> false
        ) ["handshake"; "not found"; "not reachable"; "connection"; "timeout"; "network"]
      in
      
      if is_network_error then
        (* Network/proxy issue *)
        let* () = Lwt_io.printl "Network connection failed" in
        let* () = Lwt_io.printl "" in
        let* () = Lwt_io.printl "Unable to reach remote repository (likely network/proxy issue)." in
        let* () = Lwt_io.printl "" in
        let* () = Lwt_io.printl "Solutions:" in
        let* () = Lwt_io.printl "1. Check network connectivity" in
        let* () = Lwt_io.printl "2. Try from outside corporate network/proxy" in
        let* () = Lwt_io.printl "3. Ensure using HTTPS URLs (SSH not supported)" in
        let* () = Lwt_io.printl "4. Use manual workflow:" in
        let* () = Lwt_io.printl "   cd <repo> && git pull" in
        let* () = Lwt_io.printlf "   miiify-import --input <repo> --git %s" git_path in
        Lwt.return_unit
      else
        let* () = Lwt_io.printlf "Pull failed: %s" error_msg in
        let* () = Lwt_io.printl "" in
        let* () = Lwt_io.printl "Troubleshooting:" in
        let* () = Lwt_io.printlf "- Ensure Git store exists at: %s" git_path in
        let* () = Lwt_io.printl "- Check network connectivity" in
        let* () = Lwt_io.printl "- Verify remote URL is correct" in
        Lwt.return_unit
    )
  )

let git_path =
  let doc = "Local Irmin Git store directory" in
  Arg.(value & opt string "db" & info ["git"; "g"] ~docv:"DIR" ~doc)

let remote_url =
  let doc = "Remote repository URL (e.g., https://github.com/user/repo.git)" in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"URL" ~doc)

let branch =
  let doc = "Branch name" in
  Arg.(value & opt string "main" & info ["branch"; "b"] ~docv:"BRANCH" ~doc)

let cmd =
  let doc = "Pull updates from remote and merge into Irmin Git" in
  let man = [
    `S Manpage.s_description;
    `P "Fetches updates from the remote repository and merges them into the local Irmin Git store.";
    `P "Handles conflict resolution using Irmin's merge capabilities.";
    `P "Example:";
    `Pre "  miiify-pull https://github.com/user/annotations.git";
    `Pre "  miiify-pull https://github.com/user/repo.git --git ./db-git --branch main";
  ] in
  let info = Cmd.info "pull" ~version:"0.1.0" ~doc ~man in
  Cmd.v info Term.(const pull_updates $ git_path $ remote_url $ branch)

let () =
  (* Initialize RNG for git-paf/mirage-crypto *)
  Mirage_crypto_rng_unix.use_default ();
  exit (Cmd.eval cmd)
