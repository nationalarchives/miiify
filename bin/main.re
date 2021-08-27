open Miiify;
open Lwt.Infix;

type t = {
  db: Db.t,
  container: Container.t,
};

let make_error = (status, reason) => {
  open Ezjsonm;
  let code = Dream.status_to_int(status);
  let json = dict([("code", int(code)), ("reason", string(reason))]);
  to_string(json);
};

let error_response = (status, reason) => {
  let resp = make_error(status, reason);
  Dream.json(~status, resp);
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

let get_page = request => {
  switch (Dream.query("page", request)) {
  | None => 0
  | Some(page) =>
    switch (int_of_string_opt(page)) {
    | None => 0
    | Some(value) => value
    }
  };
};

let filter_representation = prefer => {
  let lis = String.split_on_char(' ', prefer);
  List.map(x => String.split_on_char('#', x), lis);
};

let strip_last_char = str =>
  if (str == "") {
    "";
  } else {
    String.sub(str, 0, String.length(str) - 1);
  };

let get_prefer = request => {
  switch (Dream.header("prefer", request)) {
  | None => "PreferContainedDescriptions"
  | Some(prefer) =>
    switch (filter_representation(prefer)) {
    | [[_, x], ..._] => strip_last_char(x)
    | _ => "PreferContainedDescriptions"
    }
  };
};

let run = ctx =>
  Dream.run(~interface="0.0.0.0") @@
  Dream.logger @@
  Dream.router([
    Dream.get("/", _ => Dream.html("Welcome to miiify!")),
    // create container
    Dream.post("/annotations/", request => {
      Dream.body(request)
      >>= {
        body => {
          Data.post_container(
            ~data=body,
            ~id=[get_id(request), "main"],
            ~host=get_host(request),
          )
          |> {
            obj =>
              switch (obj) {
              | Error(m) => error_response(`Bad_Request, m)
              | Ok(obj) =>
                let key = Data.id(obj);
                Db.exists(~ctx=ctx.db, ~key)
                >>= (
                  ok =>
                    if (ok) {
                      error_response(
                        `Bad_Request,
                        "container already exists",
                      );
                    } else {
                      Db.add(
                        ~ctx=ctx.db,
                        ~key,
                        ~json=Data.json(obj),
                        ~message="POST " ++ key_to_string(Data.id(obj)),
                      )
                      >>= (() => Dream.json(Data.to_string(obj), ~code=201));
                    }
                );
              };
          };
        };
      }
    }),
    Dream.delete("/annotations/:container_id", request => {
      let container_id = Dream.param("container_id", request);
      let key = [container_id];
      Db.exists(~ctx=ctx.db, ~key)
      >>= {
        ok =>
          if (ok) {
            Db.delete(
              ~ctx=ctx.db,
              ~key,
              ~message="DELETE " ++ key_to_string(key),
            )
            >>= (() => Dream.empty(`No_Content));
          } else {
            error_response(`Not_Found, "container not found");
          };
      };
    }),
    // add new annotation to container
    Dream.post("/annotations/:container_id/", request => {
      Dream.body(request)
      >>= {
        body => {
          let container_id = Dream.param("container_id", request);
          Data.post_annotation(
            ~data=body,
            ~id=[container_id, "collection", get_id(request)],
            ~host=get_host(request),
          )
          |> {
            obj =>
              switch (obj) {
              | Error(m) => error_response(`Bad_Request, m)
              | Ok(obj) =>
                let key = Data.id(obj);
                // container must exist already
                Db.exists(~ctx=ctx.db, ~key=[container_id])
                >>= (
                  ok =>
                    if (ok) {
                      // annotation can't exist already
                      Db.exists(~ctx=ctx.db, ~key)
                      >>= (
                        ok =>
                          if (ok) {
                            error_response(
                              `Bad_Request,
                              "annotation already exists",
                            );
                          } else {
                            Db.add(
                              ~ctx=ctx.db,
                              ~key,
                              ~json=Data.json(obj),
                              ~message="POST " ++ key_to_string(key),
                            )
                            >>= (
                              () =>
                                Dream.json(Data.to_string(obj), ~code=201)
                            );
                          }
                      );
                    } else {
                      error_response(
                        `Bad_Request,
                        "container does not exist",
                      );
                    }
                );
              };
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
          let key = [container_id, "collection", annotation_id];
          Data.put_annotation(~data=body, ~id=key, ~host=get_host(request))
          |> {
            obj =>
              switch (obj) {
              | Error(m) => error_response(`Bad_Request, m)
              | Ok(obj) =>
                Db.exists(~ctx=ctx.db, ~key)
                >>= {
                  (
                    ok =>
                      if (ok) {
                        Db.add(
                          ~ctx=ctx.db,
                          ~key,
                          ~json=Data.json(obj),
                          ~message="PUT " ++ key_to_string(key),
                        )
                        >>= (() => Dream.json(Data.to_string(obj)));
                      } else {
                        error_response(`Bad_Request, "annotation not found");
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
      let key = [container_id, "collection", annotation_id];
      Db.exists(~ctx=ctx.db, ~key)
      >>= {
        ok =>
          if (ok) {
            Db.delete(
              ~ctx=ctx.db,
              ~key,
              ~message="DELETE " ++ key_to_string(key),
            )
            >>= (() => Dream.empty(`No_Content));
          } else {
            error_response(`Not_Found, "annotation not found");
          };
      };
    }),
    Dream.get("/annotations/:container_id/:annotation_id", request => {
      let container_id = Dream.param("container_id", request);
      let annotation_id = Dream.param("annotation_id", request);
      let key = [container_id, "collection", annotation_id];
      Db.exists(~ctx=ctx.db, ~key)
      >>= {
        ok =>
          if (ok) {
            Db.get(~ctx=ctx.db, ~key) >|= Ezjsonm.to_string >>= Dream.json;
          } else {
            error_response(`Not_Found, "annotation not found");
          };
      };
    }),
    // annotation pages
    Dream.get("/annotations/:container_id", request => {
      let container_id = Dream.param("container_id", request);
      let key = [container_id, "main"];
      let page = get_page(request);
      let prefer = get_prefer(request);
      Container.set_representation(
        ~ctx=ctx.container,
        ~representation=prefer,
      );
      Db.exists(~ctx=ctx.db, ~key)
      >>= {
        ok =>
          if (ok) {
            Container.annotation_page(
              ~ctx=ctx.container,
              ~db=ctx.db,
              ~key,
              ~page,
            )
            >>= (
              page =>
                switch (page) {
                | Some(page) => Dream.json(Ezjsonm.to_string(page))
                | None => error_response(`Not_Found, "page not found")
                }
            );
          } else {
            error_response(`Not_Found, "container not found");
          };
      };
    }),
    // annotation collection
    Dream.get("/annotations/:container_id/", request => {
      let container_id = Dream.param("container_id", request);
      let prefer = get_prefer(request);
      Container.set_representation(
        ~ctx=ctx.container,
        ~representation=prefer,
      );
      let key = [container_id, "main"];
      Db.exists(~ctx=ctx.db, ~key)
      >>= {
        ok =>
          if (ok) {
            Container.annotation_collection(
              ~ctx=ctx.container,
              ~db=ctx.db,
              ~key,
            )
            >|= Ezjsonm.to_string
            >>= Dream.json;
          } else {
            error_response(`Not_Found, "container not found");
          };
      };
    }),
  ]) @@
  Dream.not_found;

let init = () => {
  db: Db.create(~fname="db"),
  container:
    Container.create(
      ~page_limit=200,
      ~representation="PreferContainedDescriptions",
    ),
};

run(init());
