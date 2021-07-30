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

let get_id = request => {
  switch (Dream.header("Slug", request)) {
  | None => gen_uuid()
  | Some(slug) => slug
  };
};

let get_host = request => {
  Option.get(Dream.header("Host", request));
};

let key_to_string = key => {
  List.fold_left((x, y) => x ++ "/" ++ y, "", key);
};

let run = () =>
  Dream.run @@
  Dream.logger @@
  Dream.router([
    Dream.post("/annotations/", request => {
      Dream.body(request)
      >>= {
        body =>
          Data.from_post(
            ~data=body,
            ~id=[get_id(request)],
            ~host=get_host(request),
          )
          |> {
            obj =>
              switch (obj) {
              | Error(m) =>
                Dream.json(
                  ~status=`Bad_Request,
                  error_response(`Bad_Request, m),
                )
              | Ok(obj) =>
                let ctx = Option.get(ctx^).db;
                let key = Data.id(obj);
                Db.exists(~ctx, ~key)
                >>= (
                  ok =>
                    if (ok) {
                      let json = error_response(`Bad_Request, "id exists");
                      Dream.json(~status=`Bad_Request, json);
                    } else {
                      Db.add(
                        ~ctx,
                        ~key,
                        ~json=Data.json(obj),
                        ~message=
                          "CREATE container" ++ key_to_string(Data.id(obj)),
                      )
                      >>= (() => Dream.json(Data.to_string(obj), ~code=201));
                    }
                );
              };
          };
      }
    }),
    Dream.post("/annotations/:container_id/", request => {
      Dream.body(request)
      >>= {
        body =>
          Data.from_post(
            ~data=body,
            ~id=[Dream.param("container_id", request), get_id(request)],
            ~host=get_host(request),
          )
          |> {
            obj =>
              switch (obj) {
              | Error(m) =>
                Dream.json(
                  ~status=`Bad_Request,
                  error_response(`Bad_Request, m),
                )
              | Ok(obj) =>
                let ctx = Option.get(ctx^).db;
                let key = Data.id(obj);
                Db.exists(~ctx, ~key)
                >>= (
                  ok =>
                    if (ok) {
                      let json =
                        error_response(
                          `Bad_Request,
                          "annotation already exists",
                        );
                      Dream.json(~status=`Bad_Request, json);
                    } else {
                      Db.add(
                        ~ctx,
                        ~key,
                        ~json=Data.json(obj),
                        ~message="CREATE " ++ key_to_string(key),
                      )
                      >>= (() => Dream.json(Data.to_string(obj), ~code=201));
                    }
                );
              };
          };
      }
    }),
    Dream.put("/annotations/:container_id/:annotation_id", request => {
      Dream.body(request)
      >>= {
        body => {
          let container_id = Dream.param("container_id", request);
          let annotation_id = Dream.param("annotation_id", request);
          let key = [container_id, annotation_id];
          let ctx = Option.get(ctx^).db;
          Data.from_put(~data=body, ~id=key, ~host=get_host(request))
          |> {
            obj =>
              switch (obj) {
              | Error(m) =>
                Dream.json(
                  ~status=`Bad_Request,
                  error_response(`Bad_Request, m),
                )
              | Ok(obj) =>
                Db.exists(~ctx, ~key)
                >>= {
                  (
                    ok =>
                      if (ok) {
                        Db.add(
                          ~ctx,
                          ~key,
                          ~json=Data.json(obj),
                          ~message="UPDATE " ++ key_to_string(key),
                        )
                        >>= (() => Dream.json(body));
                      } else {
                        let json =
                          error_response(
                            `Bad_Request,
                            "annotation not found",
                          );
                        Dream.json(~status=`Bad_Request, json);
                      }
                  );
                }
              };
          };
        };
      }
    }),
    Dream.delete("/annotations/:container_id/:annotation_id", request => {
      let container_id = Dream.param("container_id", request);
      let annotation_id = Dream.param("annotation_id", request);
      let ctx = Option.get(ctx^).db;
      let key = [container_id, annotation_id];
      Db.exists(~ctx, ~key)
      >>= {
        ok =>
          if (ok) {
            Db.delete(~ctx, ~key, ~message="DELETE " ++ key_to_string(key))
            >>= (() => Dream.empty(`No_Content));
          } else {
            let json = error_response(`Not_Found, "annotation not found");
            Dream.json(~status=`Not_Found, json);
          };
      };
    }),
    Dream.get("/annotations/:container_id/:annotation_id", request => {
      let container_id = Dream.param("container_id", request);
      let annotation_id = Dream.param("annotation_id", request);
      let ctx = Option.get(ctx^).db;
      let key = [container_id, annotation_id];
      Db.exists(~ctx, ~key)
      >>= {
        ok =>
          if (ok) {
            Db.get(~ctx, ~key) >|= Ezjsonm.to_string >>= Dream.json;
          } else {
            let json = error_response(`Not_Found, "annotation not found");
            Dream.json(~status=`Not_Found, json);
          };
      };
    }),
  ]) @@
  Dream.not_found;

init();
run();
