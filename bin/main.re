open Miiify;
open Lwt.Infix;
open Base;

type t = {
  config: Config_t.config,
  db: Db.t,
  container: Container.t,
};

let get_root = (body, request) => {
  switch (Dream.method(request)) {
  | `GET => html_response(body)
  | `HEAD => html_empty_response(body)
  | _ => error_response(`Method_Not_Allowed, "unsupported method")
  };
};

let get_annotation = (ctx, request) => {
  let container_id = Dream.param(request, "container_id");
  let annotation_id = Dream.param(request, "annotation_id");
  let key = [container_id, "collection", annotation_id];
  Db.get_hash(~ctx=ctx.db, ~key)
  >>= {
    hash =>
      switch (hash) {
      | Some(hash) =>
        switch (get_if_none_match(request)) {
        | Some(etag) when hash == etag => Dream.empty(`Not_Modified)
        | _ =>
          Db.get(~ctx=ctx.db, ~key)
          >>= (body => json_response(~request, ~body, ~etag=Some(hash), ()))
        }
      | None => error_response(`Not_Found, "annotation not found")
      };
  };
};

let get_annotation_pages = (ctx, request) => {
  let container_id = Dream.param(request, "container_id");
  let key = [container_id, "main"];
  let page = get_page(request);
  let prefer = get_prefer(request, ctx.config.container_representation);
  Container.set_representation(~ctx=ctx.container, ~representation=prefer);
  Db.get_hash(~ctx=ctx.db, ~key)
  >>= {
    hash =>
      switch (hash) {
      | Some(hash) =>
        switch (get_if_none_match(request)) {
        | Some(etag) when hash == etag => Dream.empty(`Not_Modified)
        | _ =>
          Container.annotation_page(
            ~ctx=ctx.container,
            ~db=ctx.db,
            ~key,
            ~page,
          )
          >>= (
            page =>
              switch (page) {
              | Some(page) =>
                json_response(~request, ~body=page, ~etag=Some(hash), ())
              | None => error_response(`Not_Found, "page not found")
              }
          )
        }
      | None => error_response(`Not_Found, "container not found")
      };
  };
};

let get_annotation_collection = (ctx, request) => {
  let container_id = Dream.param(request, "container_id");
  let prefer = get_prefer(request, ctx.config.container_representation);
  Container.set_representation(~ctx=ctx.container, ~representation=prefer);
  let key = [container_id, "main"];
  Db.get_hash(~ctx=ctx.db, ~key)
  >>= {
    hash =>
      switch (hash) {
      | Some(hash) =>
        switch (get_if_none_match(request)) {
        | Some(etag) when hash == etag => Dream.empty(`Not_Modified)
        | _ =>
          Container.annotation_collection(
            ~ctx=ctx.container,
            ~db=ctx.db,
            ~key,
          )
          >>= (body => json_response(~request, ~body, ~etag=Some(hash), ()))
        }
      | None => error_response(`Not_Found, "container not found")
      };
  };
};

let delete_container = (ctx, request) => {
  let container_id = Dream.param(request, "container_id");
  let key = [container_id];
  let main_key = [container_id, "main"];
  Db.get_hash(~ctx=ctx.db, ~key=main_key)
  >>= {
    hash =>
      switch (hash) {
      | Some(hash) =>
        switch (get_if_match(request)) {
        | Some(etag) when hash == etag =>
          Db.delete(
            ~ctx=ctx.db,
            ~key,
            ~message="DELETE " ++ key_to_string(key),
          )
          >>= (() => Dream.empty(`No_Content))
        | None =>
          Db.delete(
            ~ctx=ctx.db,
            ~key,
            ~message="DELETE without etag " ++ key_to_string(key),
          )
          >>= (() => Dream.empty(`No_Content))
        | _ => Dream.empty(`Precondition_Failed)
        }
      | None => error_response(`Not_Found, "container not found")
      };
  };
};

let post_container = (ctx, request) => {
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
              yes =>
                if (yes) {
                  error_response(`Bad_Request, "container already exists");
                } else {
                  Db.add(
                    ~ctx=ctx.db,
                    ~key,
                    ~json=Data.json(obj),
                    ~message="POST " ++ key_to_string(Data.id(obj)),
                  )
                  >>= (
                    () => json_response(~request, ~body=Data.json(obj), ())
                  );
                }
            );
          };
      };
    };
  };
};

let delete_annotation = (ctx, request) => {
  let container_id = Dream.param(request, "container_id");
  let annotation_id = Dream.param(request, "annotation_id");
  let key = [container_id, "collection", annotation_id];
  Db.get_hash(~ctx=ctx.db, ~key)
  >>= {
    hash =>
      switch (hash) {
      | Some(hash) =>
        switch (get_if_match(request)) {
        | Some(etag) when hash == etag =>
          Db.delete(
            ~ctx=ctx.db,
            ~key,
            ~message="DELETE " ++ key_to_string(key),
          )
          >>= (() => Dream.empty(`No_Content))
        | None =>
          Db.delete(
            ~ctx=ctx.db,
            ~key,
            ~message="DELETE without etag " ++ key_to_string(key),
          )
          >>= (() => Dream.empty(`No_Content))
        | _ => Dream.empty(`Precondition_Failed)
        }
      | None => error_response(`Not_Found, "annotation not found")
      };
  };
};

let post_annotation = (ctx, request) => {
  Dream.body(request)
  >>= {
    body => {
      let container_id = Dream.param(request, "container_id");
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
              yes =>
                if (yes) {
                  // annotation can't exist already
                  Db.exists(~ctx=ctx.db, ~key)
                  >>= (
                    yes =>
                      if (yes) {
                        error_response(
                          `Bad_Request,
                          "annotation already exists",
                        );
                      } else {
                        let modified_key = [container_id, "main", "modified"];
                        Db.add(
                          // first modify main part of container with timestamp
                          ~ctx=ctx.db,
                          ~key=modified_key,
                          ~json=Ezjsonm.string(get_timestamp()),
                          ~message="POST " ++ key_to_string(modified_key),
                        )
                        >>= (
                          () =>
                            Db.add(
                              // add to collection part of container
                              ~ctx=ctx.db,
                              ~key,
                              ~json=Data.json(obj),
                              ~message="POST " ++ key_to_string(key),
                            )
                            >>= (
                              () =>
                                json_response(
                                  ~request,
                                  ~body=Data.json(obj),
                                  (),
                                )
                            )
                        );
                      }
                  );
                } else {
                  error_response(`Bad_Request, "container does not exist");
                }
            );
          };
      };
    };
  };
};

let put_annotation = (ctx, request) => {
  Dream.body(request)
  >>= {
    body => {
      let container_id = Dream.param(request, "container_id");
      let annotation_id = Dream.param(request, "annotation_id");
      let key = [container_id, "collection", annotation_id];
      Data.put_annotation(~data=body, ~id=key, ~host=get_host(request))
      |> {
        obj =>
          switch (obj) {
          | Error(m) => error_response(`Bad_Request, m)
          | Ok(obj) =>
            Db.get_hash(~ctx=ctx.db, ~key)
            >>= {
              (
                hash =>
                  switch (hash) {
                  | Some(hash) =>
                    switch (get_if_match(request)) {
                    | Some(etag) when hash == etag =>
                      Db.add(
                        ~ctx=ctx.db,
                        ~key,
                        ~json=Data.json(obj),
                        ~message="PUT " ++ key_to_string(key),
                      )
                      >>= (
                        () =>
                          json_response(~request, ~body=Data.json(obj), ())
                      )
                    | None =>
                      Db.add(
                        ~ctx=ctx.db,
                        ~key,
                        ~json=Data.json(obj),
                        ~message="PUT without etag " ++ key_to_string(key),
                      )
                      >>= (
                        () =>
                          json_response(~request, ~body=Data.json(obj), ())
                      )
                    | _ => Dream.empty(`Precondition_Failed)
                    }
                  | None =>
                    error_response(`Bad_Request, "annotation not found")
                  }
              );
            }
          };
      };
    };
  };
};

let run = ctx =>
  Dream.run(
    ~interface=ctx.config.interface,
    ~tls=ctx.config.tls,
    ~port=ctx.config.port,
    ~certificate_file=ctx.config.certificate_file,
    ~key_file=ctx.config.key_file,
  ) @@
  Dream.logger @@
  Dream.router([
    // route path
    Dream.options("/", _ => options_response(["OPTIONS", "HEAD", "GET"])),
    Dream.head("/", get_root(root_message)),
    Dream.get("/", get_root(root_message)),
    // create containers
    Dream.options("/annotations/", _ =>
      options_response(["OPTIONS", "POST"])
    ),
    Dream.post("/annotations/", post_container(ctx)),
    // annotations
    Dream.options("/annotations/:container_id/:annotation_id", _ =>
      options_response(["OPTIONS", "HEAD", "GET", "PUT", "DELETE"])
    ),
    Dream.head(
      "/annotations/:container_id/:annotation_id",
      get_annotation(ctx),
    ),
    Dream.get(
      "/annotations/:container_id/:annotation_id",
      get_annotation(ctx),
    ),
    Dream.put(
      "/annotations/:container_id/:annotation_id",
      put_annotation(ctx),
    ),
    Dream.delete(
      "/annotations/:container_id/:annotation_id",
      delete_annotation(ctx),
    ),
    // container collections
    Dream.options("/annotations/:container_id/", _ =>
      options_response(["OPTIONS", "HEAD", "GET", "POST", "DELETE"])
    ),
    Dream.head(
      "/annotations/:container_id/",
      get_annotation_collection(ctx),
    ),
    Dream.get("/annotations/:container_id/", get_annotation_collection(ctx)),
    Dream.post("/annotations/:container_id/", post_annotation(ctx)),
    Dream.delete("/annotations/:container_id/", delete_container(ctx)),
    // container pages
    Dream.options("/annotations/:container_id", _ =>
      options_response(["OPTIONS", "HEAD", "GET"])
    ),
    Dream.head("/annotations/:container_id", get_annotation_pages(ctx)),
    Dream.get("/annotations/:container_id", get_annotation_pages(ctx)),
  ])

let init = config => {
  config,
  db:
    Db.create(
      ~fname=config.repository_name,
      ~author=config.repository_author,
    ),
  container:
    Container.create(
      ~page_limit=config.container_page_limit,
      ~representation=config.container_representation,
    ),
};

let config_file = ref("");

let parse_cmdline = () => {
  let usage = "usage: " ++ Sys.argv[0];
  let speclist = [
    (
      "--config",
      Arg.Set_string(config_file),
      ": to specify the configuration file to use",
    ),
  ];
  Arg.parse(speclist, x => raise(Arg.Bad("Bad argument : " ++ x)), usage);
};

let configure = () => {
  parse_cmdline();
  let data =
    switch (config_file^) {
    | "" => "{}"
    | fname => read_file(fname)
    };
  switch (Config.parse(~data)) {
  | Error(message) => failwith(message)
  | Ok(config) => run(init(config))
  };
};

configure();