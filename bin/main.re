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

let error_response = (status, reason) => {
  open Ezjsonm;
  let code = Dream.status_to_int(status);
  let json = dict([("code", int(code)), ("reason", string(reason))]);
  to_string(json);
};

let gen_uuid = () =>
  Uuidm.v4_gen(Random.State.make_self_init(), ()) |> Uuidm.to_string;


let get_id = (request) => {
  switch (Dream.header("Slug", request)) {
    | None => gen_uuid();
    | Some(slug) => slug;
  }
}


let get_host = (request) => {
  Option.get(Dream.header("Host", request))
}


let run = () =>
  Dream.run @@
  Dream.logger @@
  Dream.router([
    Dream.post("/annotations/", request => {
      Dream.body(request)
      >>= {
        body =>
          Data.from_post(~data=body, ~id=get_id(request), ~host=get_host(request))
          |> {
            obj =>
              Db.add(
                ~ctx=Option.get(ctx^).db,
                ~key=Data.id(obj),
                ~json=Data.json(obj),
                ~message="CREATE " ++ Data.id(obj),
              )
              >>= (() => Dream.json(Data.to_string(obj), ~code=201));
          };
      }
    }),
    Dream.put("/annotations/:id", request => {
      Dream.body(request)
      >>= {
        body =>
          Data.from_put(~data=body)
          |> {
            obj => {
              let id = Dream.param("id", request);
              let ctx = Option.get(ctx^).db;
              Db.exists(~ctx, ~key=id)
              >>= {
                ok =>
                  if (ok) {
                    // make sure the id's match
                    if (id == Data.id(obj)) {
                      Db.add(
                        ~ctx,
                        ~key=id,
                        ~json=Data.json(obj),
                        ~message="UPDATE " ++ id,
                      )
                      >>= (() => Dream.json(body));
                    } else {
                      let json =
                        error_response(
                          `Bad_Request,
                          "id in body does not match path parameter",
                        );
                      Dream.json(~status=`Bad_Request, json);
                    };
                  } else {
                    let json = error_response(`Not_Found, "id not found");
                    Dream.json(~status=`Not_Found, json);
                  };
              };
            };
          };
      }
    }),
    Dream.delete("/annotations/:id", request => {
      let id = Dream.param("id", request);
      let ctx = Option.get(ctx^).db;
      Db.exists(~ctx, ~key=id)
      >>= {
        ok =>
          if (ok) {
            Db.delete(~ctx, ~key=id, ~message="DELETE " ++ id)
            >>= (() => Dream.empty(`No_Content));
          } else {
            let json = error_response(`Not_Found, "id not found");
            Dream.json(~status=`Not_Found, json);
          };
      };
    }),
    Dream.get("/annotations/:id", request => {
      let id = Dream.param("id", request);
      let ctx = Option.get(ctx^).db;
      Db.exists(~ctx, ~key=id)
      >>= {
        ok =>
          if (ok) {
            Db.get(~ctx, ~key=id) >|= Ezjsonm.to_string >>= Dream.json;
          } else {
            let json = error_response(`Not_Found, "id not found");
            Dream.json(~status=`Not_Found, json);
          };
      };
    }),
  ]) @@
  Dream.not_found;

init();
run();
