(** Miiify - Main command dispatcher *)

open Cmdliner

let () =
  
  (* Subcommands *)
  let clone_cmd = 
    let doc = "Clone remote Git repository as bare repository" in
    let info = Cmd.info "clone" ~version:"0.1.0" ~doc in
    Cmd.v info (Term.ret (Term.const (`Help (`Auto, None))))
  in
  
  let pull_cmd =
    let doc = "Pull updates from remote and merge into Git store" in
    let info = Cmd.info "pull" ~version:"0.1.0" ~doc in
    Cmd.v info (Term.ret (Term.const (`Help (`Auto, None))))
  in
  
  let import_cmd =
    let doc = "Import JSON annotation files into Git store" in
    let info = Cmd.info "import" ~version:"0.1.0" ~doc in
    Cmd.v info (Term.ret (Term.const (`Help (`Auto, None))))
  in
  
  let compile_cmd =
    let doc = "Compile Git store into optimized Pack store" in
    let info = Cmd.info "compile" ~version:"0.1.0" ~doc in
    Cmd.v info (Term.ret (Term.const (`Help (`Auto, None))))
  in
  
  let serve_cmd =
    let doc = "Serve miiify API from Git or Pack store" in
    let info = Cmd.info "serve" ~version:"0.1.0" ~doc in
    Cmd.v info (Term.ret (Term.const (`Help (`Auto, None))))
  in
  
  let default_cmd =
    let doc = "Web annotation server with Git and Pack backends" in
    let man = [
      `S Manpage.s_description;
      `P "Miiify is a lightweight web annotation server implementing the W3C Web Annotation Protocol.";
      `P "It separates human collaboration (Git) from machine queries (Pack) for optimal workflows.";
      `P "See 'miiify COMMAND --help' for subcommand usage.";
      `S Manpage.s_commands;
      `P "clone - Clone remote Git repository";
      `P "pull - Pull updates from remote";
      `P "import - Import JSON files (dev only)";
      `P "compile - Compile Git to Pack";
      `P "serve - Serve API from Git or Pack";
    ] in
    let info = Cmd.info "miiify" ~version:"0.1.0" ~doc ~man in
    Cmd.group info [clone_cmd; pull_cmd; import_cmd; compile_cmd; serve_cmd]
  in
  
  exit (Cmd.eval default_cmd)
