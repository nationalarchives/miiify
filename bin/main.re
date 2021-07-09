open Miiify;
open Lwt.Infix;

let () =
  Dream.run @@
  Dream.logger @@
  Dream.router([
    Dream.post("/annotations/", request => {
      Dream.body(request)
      >|= Annotation.create
      >>= (
        obj => {
          Annotation.id(obj) |> Dream.json;
        }
      )
    }),
  ]) @@
  Dream.not_found;