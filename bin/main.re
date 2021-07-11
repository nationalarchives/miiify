open Miiify;
open Lwt.Infix;

// store our context
type t = {db: Db.t};

// not initialised yet
let ctx = ref(None);

let init = () => {
  ctx := Some({db: Db.create(~fname="db")});
  Dream.log("Initialised the database");
};

let run = () =>
  Dream.run @@
  Dream.logger @@
  Dream.router([
    Dream.post("/annotations/", request => {
      Dream.body(request)
      >>= (
        data =>
          Annotation.create(data)
          |> (
            obj =>
              Db.add(
                ~ctx=Option.get(ctx^).db,
                ~key=Annotation.id(obj),
                ~data=Ezjsonm.from_string(data),
              )
              >>= (() => Dream.html("Good morning, world!"))
          )
      )
    }),
    Dream.get("/annotations/:id", request => {
      Db.get(~ctx=Option.get(ctx^).db, ~key=Dream.param("id", request))
      >|= Ezjsonm.to_string
      >>= Dream.json
    }),
  ]) @@
  Dream.not_found;

init();
run();
