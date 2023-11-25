open Miiify.Db
open Ezjsonm
open Lwt.Infix
open Lwt_io

let key = [ "k" ]
let j1 = dict [ ("test", string "hello world") ]
let j2 = dict [ ("test", string "hello world again") ]

let crud () =
  let ctx = create ~fname:"db" ~author:"miiify test" in
  add ~ctx ~key ~json:j1 ~message:"CREATE" >>= fun () ->
  count ~ctx ~key >>= fun n ->
  printf "%d\n" n >>= fun () ->
  get ~ctx ~key >>= fun j ->
  printf "%s\n" (value_to_string j) >>= fun () ->
  add ~ctx ~key ~json:j2 ~message:"UPDATE" >>= fun () ->
  count ~ctx ~key >>= fun n ->
  printf "%d\n" n >>= fun () ->
  get ~ctx ~key >>= fun j ->
  printf "%s\n" (value_to_string j) >>= fun () ->
  delete ~ctx ~key ~message:"DELETE" >>= fun () ->
  count ~ctx ~key >>= fun n -> printf "%d\n" n

let () = Lwt_main.run @@ crud ()
