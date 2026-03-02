(** Push local changes to remote Git repository *)

open Lwt.Syntax
open Cmdliner

module Store = Irmin_git_unix.FS.KV(Irmin.Contents.String)
module Sync = Irmin.Sync.Make(Store)

let run_push ~git_path ~remote_url ~branch =
  let* () = Lwt_io.printl "Miiify Push" in
  let* () = Lwt_io.printlf "Store:  %s" git_path in
  let* () = Lwt_io.printlf "Remote: %s" remote_url in
  let* () = Lwt_io.printlf "Branch: %s" branch in
  let* () = Lwt_io.printl "" in

  Lwt.catch
    (fun () ->
      let* () = Lwt_io.printl "Opening Git store..." in
      let config = Irmin_git.config ~bare:true git_path in
      let* repo = Store.Repo.v config in
      let* store = Store.main repo in

      let* () = Lwt_io.printl "Pushing to remote..." in
      let* remote_ref = Store.remote remote_url in

      (* Push to remote *)
      let* result = Sync.push store remote_ref in

      match result with
      | Ok (`Head _) ->
          let* () = Lwt_io.printl "Successfully pushed updates" in
          let* () = Lwt_io.printlf "Remote updated: %s" remote_url in
          Lwt.return_unit
      | Ok `Empty ->
          let* () = Lwt_io.printl "No updates to push (already up to date)" in
          Lwt.return_unit
      | Error `Detached_head ->
          let* () = Lwt_io.eprintl "✗ Push failed: detached HEAD state" in
          let* () =
            Lwt_io.eprintl "The repository is in a detached HEAD state"
          in
          Lwt.fail (Failure "detached HEAD")
      | Error (`Msg msg) ->
          let* () = Lwt_io.eprintlf "✗ Push failed: %s" msg in
          let* () = Lwt_io.eprintl "You may need to pull remote changes first" in
          Lwt.fail (Failure msg))
    (fun exn ->
      let error_msg = Printexc.to_string exn in

      (* Detect permission/authentication errors *)
      let is_permission_error =
        String.lowercase_ascii error_msg
        |> fun msg ->
        List.exists
          (fun pattern ->
            try Str.search_forward (Str.regexp_case_fold pattern) msg 0 >= 0
            with Not_found -> false)
          [ "permission";
            "denied";
            "authentication";
            "unauthorized";
            "forbidden";
            "repository not found";
            "not found";
            "no anonymous write access";
            "anonymous write"
          ]
      in

      (* Detect network/connectivity errors *)
      let is_network_error =
        String.lowercase_ascii error_msg
        |> fun msg ->
        List.exists
          (fun pattern ->
            try Str.search_forward (Str.regexp_case_fold pattern) msg 0 >= 0
            with Not_found -> false)
          [ "handshake"; "not reachable"; "connection"; "timeout"; "network" ]
      in

      if is_permission_error then (
        let* () = Lwt_io.eprintl "Authentication required" in
        let* () = Lwt_io.eprintl "" in
        let* () = Lwt_io.eprintl "Push requires authentication." in
        let* () = Lwt_io.eprintl "" in
        let* () = Lwt_io.eprintl "Option 1: Use GitHub Personal Access Token" in
        let* () =
          Lwt_io.eprintl
            "  1. Generate token: github.com → Settings → Developer settings → Tokens"
        in
        let* () = Lwt_io.eprintl "  2. Use token in URL:" in
        let* () =
          Lwt_io.eprintlf
            "     miiify-push https://<TOKEN>@github.com/user/repo.git --git %s"
            git_path
        in
        let* () = Lwt_io.eprintl "" in
        let* () = Lwt_io.eprintl "Option 2: Use manual git push (recommended)" in
        let* () = Lwt_io.eprintlf "  cd %s" git_path in
        let* () =
          Lwt_io.eprintl "  git remote add origin https://github.com/user/repo.git"
        in
        let* () = Lwt_io.eprintl "  git push origin main" in
        let* () = Lwt_io.eprintl "" in
        let* () =
          Lwt_io.eprintl
            "Note: SSH URLs (git@github.com:...) are not currently supported."
        in
        Lwt.fail (Failure "Authentication required")
      ) else if is_network_error then (
        let* () = Lwt_io.eprintl "Network connection failed" in
        let* () = Lwt_io.eprintl "" in
        let* () =
          Lwt_io.eprintl
            "Unable to reach remote repository (likely network/proxy issue)."
        in
        let* () = Lwt_io.eprintl "" in
        let* () = Lwt_io.eprintl "Solutions:" in
        let* () = Lwt_io.eprintl "1. Check network connectivity" in
        let* () = Lwt_io.eprintl "2. Try from outside corporate network/proxy" in
        let* () = Lwt_io.eprintl "3. Use manual workflow:" in
        let* () =
          Lwt_io.eprintlf "   cd %s && git push %s %s" git_path remote_url
            branch
        in
        Lwt.fail (Failure "Network connection failed")
      ) else (
        let* () = Lwt_io.eprintlf "Push failed: %s" error_msg in
        let* () = Lwt_io.eprintl "" in
        let* () = Lwt_io.eprintl "Troubleshooting:" in
        let* () = Lwt_io.eprintlf "- Ensure Git store exists at: %s" git_path in
        let* () = Lwt_io.eprintl "- Check network connectivity" in
        let* () = Lwt_io.eprintl "- Verify remote URL and write permissions" in
        Lwt.fail (Failure "Push failed")
      ))

let push_updates git_path remote_url branch =
  let result =
    Lwt_main.run
      (Lwt.catch
         (fun () ->
           let* () = run_push ~git_path ~remote_url ~branch in
           Lwt.return (Ok ()))
         (fun exn -> Lwt.return (Error exn)))
  in
  match result with
  | Ok () -> ()
  | Error exn ->
      (* Avoid Cmdliner backtraces: errors are already printed near the source. *)
      (match exn with
      | Failure _ -> ()
      | _ -> Printf.eprintf "Error: %s\n" (Printexc.to_string exn));
      exit 1

let git_path =
  let doc = "Local Irmin Git store directory" in
  Arg.(value & opt string "git_store" & info ["git"; "g"] ~docv:"DIR" ~doc)

let remote_url =
  let doc = "Remote repository URL (e.g., https://github.com/user/repo.git)" in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"URL" ~doc)

let branch =
  let doc = "Branch name" in
  Arg.(value & opt string "main" & info ["branch"; "b"] ~docv:"BRANCH" ~doc)

let cmd =
  let doc = "Push local changes to remote Git repository" in
  let man = [
    `S Manpage.s_description;
    `P "Pushes local changes from the Irmin Git store to a remote repository.";
    `P "Use this to sync local annotations back to GitHub or another Git remote.";
    `P "Example:";
    `Pre "  miiify-push https://github.com/user/annotations.git";
    `Pre "  miiify-push https://github.com/user/repo.git --git ./git_store --branch main";
  ] in
  let info = Cmd.info "push" ~version:"0.1.0" ~doc ~man in
  Cmd.v info Term.(const push_updates $ git_path $ remote_url $ branch)

let () =
  (* Initialize RNG for git-paf/mirage-crypto *)
  Mirage_crypto_rng_unix.use_default ();
  exit (Cmd.eval cmd)
