open Miiify.Db;
open Ezjsonm;
open Lwt.Infix;
open Lwt_io;

let key = ["k"];

let j1 = dict([("test", string("hello world"))]);
let j2 = dict([("test", string("hello world again"))]);

let crud = () => {
  let ctx = create(~fname="db", ~author="miiify test");
  add(~ctx, ~key, ~json=j1, ~message="CREATE")
  >>= (() => count(~ctx, ~key) >>= (n => printf("%d\n", n)))
  >>= (() => get(~ctx, ~key) >>= (j => printf("%s\n", value_to_string(j))))
  >>= (() => add(~ctx, ~key, ~json=j2, ~message="UPDATE"))
  >>= (() => count(~ctx, ~key) >>= (n => printf("%d\n", n)))
  >>= (() => get(~ctx, ~key) >>= (j => printf("%s\n", value_to_string(j))))
  >>= (() => delete(~ctx, ~key, ~message="DELETE"))
  >>= (() => count(~ctx, ~key) >>= (n => printf("%d\n", n)));
};

Lwt_main.run(crud());