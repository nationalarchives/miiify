open Miiify

let () =
  let config = Utils.Cmd.parse () in
  let db = Model.create ~config in
  Dream.run ~interface:config.interface ~tls:config.tls ~port:config.port
    ~certificate_file:config.certificate_file ~key_file:config.key_file
  @@ Dream.logger
  @@ Dream.router
       [
         Dream.get "/" (View.status config db);
         Dream.get "/version" (View.version config db);
         Dream.post "/annotations/" (View.post_container config db);
         Dream.put "/annotations/:container_id" (View.put_container config db);
         Dream.delete "/annotations/:container_id"
           (View.delete_container config db);
         Dream.post "/annotations/:container_id/"
           (View.post_annotation config db);
         Dream.get "/annotations/:container_id/" (View.get_container config db);
         Dream.get "/annotations/:container_id/:annotation_id"
           (View.get_annotation config db);
         Dream.delete "/annotations/:container_id/:annotation_id"
           (View.delete_annotation config db);
         Dream.put "/annotations/:container_id/:annotation_id"
           (View.put_annotation config db);
         Dream.post "/manifest/:manifest_id" (View.post_manifest config db);
         Dream.get "/manifest/:manifest_id" (View.get_manifest config db);
         Dream.put "/manifest/:manifest_id" (View.put_manifest config db);
         Dream.delete "/manifest/:manifest_id" (View.delete_manifest config db);
       ]
