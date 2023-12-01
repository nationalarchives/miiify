open Miiify

let () =
  let config = Utils.Cmd.parse () in
  let db = Model.create ~config in
  Dream.run ~interface:config.interface ~tls:config.tls ~port:config.port
    ~certificate_file:config.certificate_file ~key_file:config.key_file
  @@ Dream.logger
  @@ Dream.router
       [
         Dream.get "/" (View.get_status config);
         Dream.head "/" (View.head_status config);
         Dream.get "/version" (View.get_version config);
         Dream.head "/version" (View.head_version config);
         Dream.post "/annotations/" (View.post_container db);
         Dream.put "/annotations/:container_id" (View.put_container config db);
         Dream.delete "/annotations/:container_id"
           (View.delete_container config db);
         Dream.post "/annotations/:container_id/" (View.post_annotation db);
         Dream.get "/annotations/:container_id/"
           (View.get_annotations config db);
         Dream.head "/annotations/:container_id/"
           (View.head_annotations config db);
         Dream.get "/annotations/:container_id" (View.get_container db);
         Dream.head "/annotations/:container_id" (View.head_container db);
         Dream.get "/annotations/:container_id/:annotation_id"
           (View.get_annotation db);
         Dream.head "/annotations/:container_id/:annotation_id"
           (View.head_annotation db);
         Dream.delete "/annotations/:container_id/:annotation_id"
           (View.delete_annotation config db);
         Dream.put "/annotations/:container_id/:annotation_id"
           (View.put_annotation config db);
         Dream.post "/manifest/:manifest_id" (View.post_manifest db);
         Dream.get "/manifest/:manifest_id" (View.get_manifest db);
         Dream.head "/manifest/:manifest_id" (View.head_manifest db);
         Dream.put "/manifest/:manifest_id" (View.put_manifest config db);
         Dream.delete "/manifest/:manifest_id" (View.delete_manifest config db);
       ]
