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

let error_response = (code, reason) => {
  open Ezjsonm;
  let json = dict([("code", int(code)), ("reason", string(reason))]);
  to_string(json);
};

let error_template = (debug_info, suggested_response) => {
  let status = Dream.status(suggested_response);
  let code = Dream.status_to_int(status)
  and reason = Dream.status_to_string(status);
  Dream.json(error_response(code, reason), ~code);
};

let run = () =>
  Dream.run(~error_handler=Dream.error_template(error_template)) @@
  Dream.logger @@
  Dream.router([
    Dream.post("/annotations/", request => {
      Dream.body(request)
      >>= {
        body =>
          Data.convert(body)
          |> {
            obj =>
              Db.add(
                ~ctx=Option.get(ctx^).db,
                ~key=Data.id(obj),
                ~json=Data.json(obj),
                ~message="CREATE " ++ Data.id(obj),
              )
              >>= (() => Dream.json(body, ~code=201));
          };
      }
    }),
    Dream.put("/annotations/:id", request => {
      Dream.body(request)
      >>= {
        body =>
          Data.convert(body)
          |> {
            obj => {
              let id = Dream.param("id", request);
              // make sure the id's match
              if (id == Data.id(obj)) {
                Db.add(
                  ~ctx=Option.get(ctx^).db,
                  ~key=id,
                  ~json=Data.json(obj),
                  ~message="UPDATE " ++ id,
                )
                >>= (() => Dream.json(body));
              } else {
                Dream.empty(`Bad_Request);
              };
            };
          };
      }
    }),
    Dream.delete("/annotations/:id", request => {
      let id = Dream.param("id", request);
      Db.delete(~ctx=Option.get(ctx^).db, ~key=id, ~message="DELETE " ++ id)
      >>= (() => Dream.empty(`No_Content));
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
