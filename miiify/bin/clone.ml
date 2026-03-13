(** Clone remote Git repository into Irmin Git store *)

open Lwt.Syntax
open Cmdliner

module Store = Irmin_git_unix.FS.KV(Irmin.Contents.String)
module Sync = Irmin.Sync.Make(Store)

let dir_is_nonempty path =
  match Sys.readdir path |> Array.to_list with
  | [] -> false
  | items ->
      (* treat any entry (including hidden) as non-empty; this is a safety check *)
      List.length items > 0

let run_clone ~repo_url ~git_path =
  let* () = Lwt_io.printl "Miiify Clone" in
  let* () = Lwt_io.printlf "Remote: %s" repo_url in
  let* () = Lwt_io.printlf "Local:  %s" git_path in
  let* () = Lwt_io.printl "" in

  (* Refuse to clone into an existing non-empty directory. *)
  let* () =
    if Sys.file_exists git_path then (
      if not (Sys.is_directory git_path) then (
        let* () =
          Lwt_io.eprintlf
            "Error: --git path exists and is not a directory: %s"
            git_path
        in
        Lwt.fail (Failure "Invalid --git path")
      ) else if dir_is_nonempty git_path then (
        let* () =
          Lwt_io.eprintlf
            "Error: --git directory already exists and is not empty: %s"
            git_path
        in
        let* () =
          Lwt_io.eprintl
            "Remove it first if you want to start fresh: rm -rf <git-path>"
        in
        Lwt.fail (Failure "Refusing to clone into non-empty directory")
      ) else
        Lwt.return_unit
    ) else
      Lwt.return_unit
  in

  Lwt.catch
    (fun () ->
      let* () = Lwt_io.printl "Initializing Git store..." in
      let config = Irmin_git.config ~bare:true git_path in
      let* repo = Store.Repo.v config in
      let* store = Store.main repo in

      let* () = Lwt_io.printl "Fetching from remote..." in
      let* remote = Store.remote repo_url in

      (* Fetch from remote - this will pull all branches and refs *)
      let* result = Sync.fetch store remote in

      match result with
      | Ok (`Head head_ref) ->
          (* Set HEAD to point to the fetched branch *)
          let* () = Store.Head.set store head_ref in
          let* () = Lwt_io.printl "Successfully cloned repository" in
          let* () = Lwt_io.printlf "Git store ready at: %s" git_path in
          Lwt.return_unit
      | Ok `Empty ->
          let* () = Lwt_io.eprintl "Warning: Remote repository is empty" in
          Lwt.return_unit
      | Error (`Msg msg) ->
          let* () = Lwt_io.eprintlf "✗ Fetch failed: %s" msg in
          Lwt.fail (Failure msg))
    (fun exn ->
      let error_msg = Printexc.to_string exn in

      (* Detect network/connectivity errors *)
      let is_network_error =
        String.lowercase_ascii error_msg
        |> fun msg ->
        List.exists
          (fun pattern ->
            try Str.search_forward (Str.regexp_case_fold pattern) msg 0 >= 0
            with Not_found -> false)
          [ "handshake"; "not found"; "not reachable"; "connection"; "timeout"; "network" ]
      in

      if is_network_error then (
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
        let* () = Lwt_io.eprintl "3. Use HTTPS URLs (SSH not supported)" in
        let* () = Lwt_io.eprintl "4. Use manual workflow:" in
        let* () = Lwt_io.eprintlf "   git clone %s" repo_url in
        let* () =
          Lwt_io.eprintlf "   miiify-import --input <cloned-dir> --git %s"
            git_path
        in
        Lwt.fail (Failure "Network connection failed")
      ) else (
        let* () = Lwt_io.eprintlf "Clone failed: %s" error_msg in
        let* () = Lwt_io.eprintl "" in
        let* () = Lwt_io.eprintl "Troubleshooting:" in
        let* () = Lwt_io.eprintl "- Check repository URL is correct (use HTTPS)" in
        let* () =
          Lwt_io.eprintl
            "- For private repos, use token: https://TOKEN@github.com/user/repo.git"
        in
        let* () = Lwt_io.eprintl "- Check network connectivity" in
        let* () = Lwt_io.eprintl "" in
        let* () =
          Lwt_io.eprintl
            "Note: SSH URLs (git@github.com:...) are not currently supported."
        in
        Lwt.fail (Failure "Clone failed")
      ))

let clone_repo repo_url git_path =
  let result =
    Lwt_main.run
      (Lwt.catch
         (fun () ->
           let* () = run_clone ~repo_url ~git_path in
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

let repo_url =
  let doc = "Remote Git repository URL" in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"REPO_URL" ~doc)

let git_path =
  let doc = "Local Irmin Git store directory" in
  Arg.(value & opt string "git_store" & info ["git"; "g"] ~docv:"DIR" ~doc)

let cmd =
  let doc = "Clone remote Git repository into Irmin Git store" in
  let man = [
    `S Manpage.s_description;
    `P "Clones a remote Git repository into a local Irmin Git store.";
    `P "Fetches from remote using Irmin's native sync mechanism.";
    `P "Refuses to clone into an existing non-empty --git directory. Remove it first if needed.";
    `P "Example:";
    `Pre "  miiify-clone https://github.com/org/annotations.git";
    `Pre "  miiify-clone https://github.com/org/annotations.git --git ./my-db";
  ] in
  let info = Cmd.info "clone" ~version:"0.1.0" ~doc ~man in
  Cmd.v info Term.(const clone_repo $ repo_url $ git_path)

let () =
  (* Initialize RNG for git-paf/mirage-crypto *)
  Mirage_crypto_rng_unix.use_default ();
  exit (Cmd.eval cmd)
