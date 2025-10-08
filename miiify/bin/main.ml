open Miiify
open Lwt.Syntax

let config = Utils.Cmd.parse ()

let cors handler req =
  let handlers =
    [
      ("Access-Control-Allow-Origin", config.access_control_allow_origin);
      ("Access-Control-Max-Age", config.access_control_max_age);
    ]
  in
  let* res = handler req in
  handlers
  |> List.map (fun (key, value) -> Dream.add_header res key value)
  |> ignore;
  Lwt.return res

let () =
  let db = Lwt_main.run (Model.create ~config) in
  Dream.run ~interface:config.interface ~tls:config.tls ~port:config.port
    ~certificate_file:config.certificate_file ~key_file:config.key_file
  @@ Dream.logger @@ cors
  @@ Dream.router
       [
         (* /status *)
         Dream.get "/" (View.get_status config);
         Dream.head "/" (View.head_status config);
         Dream.options "/" View.options_status;
         (* /version *)
         Dream.get "/version" (View.get_version config);
         Dream.head "/version" (View.head_version config);
         Dream.options "/version" View.options_version;
         (* /annotations/ *)
         Dream.post "/annotations/" (View.post_container config db);
         Dream.options "/annotations/" View.options_create_container;
         (* /annotations/:container_id *)
         Dream.get "/annotations/:container_id" (View.get_container db);
         Dream.head "/annotations/:container_id" (View.head_container db);
         Dream.put "/annotations/:container_id" (View.put_container config db);
         Dream.delete "/annotations/:container_id"
           (View.delete_container config db);
         Dream.options "/annotations/:container_id" View.options_container;
         (* /annotations/:container_id/ *)
         Dream.post "/annotations/:container_id/"
           (View.post_annotation config db);
         Dream.get "/annotations/:container_id/"
           (View.get_annotations config db);
         Dream.options "/annotations/:container_id/" View.options_annotations;
         Dream.head "/annotations/:container_id/"
           (View.head_annotations config db);
         (* /annotations/:container_id/:annotation_id *)
         Dream.get "/annotations/:container_id/:annotation_id"
           (View.get_annotation db);
         Dream.options "/annotations/:container_id/:annotation_id"
           View.options_annotation;
         Dream.head "/annotations/:container_id/:annotation_id"
           (View.head_annotation db);
         Dream.delete "/annotations/:container_id/:annotation_id"
           (View.delete_annotation config db);
         Dream.put "/annotations/:container_id/:annotation_id"
           (View.put_annotation config db);
         (* /manifest/:manifest_id *)
         Dream.post "/manifest/:manifest_id" (View.post_manifest db);
         Dream.get "/manifest/:manifest_id" (View.get_manifest db);
         Dream.head "/manifest/:manifest_id" (View.head_manifest db);
         Dream.put "/manifest/:manifest_id" (View.put_manifest config db);
         Dream.delete "/manifest/:manifest_id" (View.delete_manifest config db);
         Dream.options "/manifest/:manifest_id" View.options_manifest;
       ]
