(** Serve miiify API from Pack store only *)

open Cmdliner

let serve repository_name port page_limit =
  (* Initialize Pack store first *)
  let db = Lwt_main.run (
    let open Lwt.Syntax in
    let* () = Lwt_io.printl "Miiify Server" in
    let* () = Lwt_io.printlf "Repository: %s" repository_name in
    Miiify.Model.create ~repository_name
  ) in
  
  (* Then start Dream server (which takes over event loop) *)
  Printf.printf "Starting API server on port %d\n" port;
  Printf.printf "Page limit: %d\n%!" page_limit;
  
  Dream.run ~interface:"0.0.0.0" ~port
  @@ Dream.logger
  @@ Dream.router
       [
         (* Status and version endpoints *)
         Dream.get "/" Miiify.Api.get_status;
         Dream.get "/version" Miiify.Api.get_version;
         
         (* Read-only annotation endpoints *)
         Dream.get "/annotations/:container_id" (Miiify.Api.get_container db);
         Dream.get "/annotations/:container_id/" (Miiify.Api.get_annotations page_limit db);
         Dream.get "/annotations/:container_id/:annotation_id" (Miiify.Api.get_annotation db);
       ]

let repository_arg =
  let doc = "Repository directory path" in
  Arg.(value & opt string "db" & info ["repository"; "r"] ~docv:"DIR" ~doc)

let port_arg =
  let doc = "Server port" in
  Arg.(value & opt int 10000 & info ["port"; "p"] ~docv:"PORT" ~doc)

let page_limit_arg =
  let doc = "Maximum items per page" in
  Arg.(value & opt int 200 & info ["page-limit"] ~docv:"NUM" ~doc)

let cmd =
  let doc = "Run miiify annotation server" in
  let man = [
    `S Manpage.s_description;
    `P "Starts a read-only web annotation server backed by Irmin Pack store.";
    `P "Example:";
    `Pre "  miiify-serve --repository ./db-pack --port 10000";
  ] in
  let info = Cmd.info "serve" ~version:"0.1.0" ~doc ~man in
  Cmd.v info Term.(const serve $ repository_arg $ port_arg $ page_limit_arg)

let () =
  exit (Cmd.eval cmd)
