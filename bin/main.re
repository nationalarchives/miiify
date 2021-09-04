open Miiify;
open Lwt.Infix;
open Base;

type t = {
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
  let container_id = Dream.param("container_id", request);
  let annotation_id = Dream.param("annotation_id", request);
  let key = [container_id, "collection", annotation_id];
  Db.exists(~ctx=ctx.db, ~key)
  >>= {
    yes =>
      if (yes) {
        Db.get(~ctx=ctx.db, ~key) >>= json_response(request);
      } else {
        error_response(`Not_Found, "annotation not found");
      };
  };
};

let get_annotation_pages = (ctx, request) => {
  let container_id = Dream.param("container_id", request);
  let key = [container_id, "main"];
  let page = get_page(request);
  let prefer = get_prefer(request);
  Container.set_representation(~ctx=ctx.container, ~representation=prefer);
  Db.exists(~ctx=ctx.db, ~key)
  >>= {
    yes =>
      if (yes) {
        Container.annotation_page(~ctx=ctx.container, ~db=ctx.db, ~key, ~page)
        >>= (
          page =>
            switch (page) {
            | Some(page) => json_response(request, page)
            | None => error_response(`Not_Found, "page not found")
            }
        );
      } else {
        error_response(`Not_Found, "container not found");
      };
  };
};

let get_annotation_collection = (ctx, request) => {
  let container_id = Dream.param("container_id", request);
  let prefer = get_prefer(request);
  Container.set_representation(~ctx=ctx.container, ~representation=prefer);
  let key = [container_id, "main"];
  Db.exists(~ctx=ctx.db, ~key)
  >>= {
    yes =>
      if (yes) {
        Container.annotation_collection(~ctx=ctx.container, ~db=ctx.db, ~key)
        >>= json_response(request);
      } else {
        error_response(`Not_Found, "container not found");
      };
  };
};

let delete_container = (ctx, request) => {
  let container_id = Dream.param("container_id", request);
  let key = [container_id];
  Db.exists(~ctx=ctx.db, ~key)
  >>= {
    yes =>
      if (yes) {
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
                  >>= (() => json_response(request, Data.json(obj)));
                }
            );
          };
      };
    };
  };
};

let delete_annotation = (ctx, request) => {
  let container_id = Dream.param("container_id", request);
  let annotation_id = Dream.param("annotation_id", request);
  let key = [container_id, "collection", annotation_id];
  Db.exists(~ctx=ctx.db, ~key)
  >>= {
    yes =>
      if (yes) {
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
};

let post_annotation = (ctx, request) => {
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
                        Db.add(
                          ~ctx=ctx.db,
                          ~key,
                          ~json=Data.json(obj),
                          ~message="POST " ++ key_to_string(key),
                        )
                        >>= (() => json_response(request, Data.json(obj)));
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
                yes =>
                  if (yes) {
                    Db.add(
                      ~ctx=ctx.db,
                      ~key,
                      ~json=Data.json(obj),
                      ~message="PUT " ++ key_to_string(key),
                    )
                    >>= (() => json_response(request, Data.json(obj)));
                  } else {
                    error_response(`Bad_Request, "annotation not found");
                  }
              );
            }
          };
      };
    };
  };
};

let run = ctx =>
  Dream.run(~interface="0.0.0.0") @@
  Dream.logger @@
  Dream.router([
    Dream.head(
      "/annotations/:container_id/:annotation_id",
      get_annotation(ctx),
    ),
    Dream.head("/annotations/:container_id", get_annotation_pages(ctx)),
    Dream.head(
      "/annotations/:container_id/",
      get_annotation_collection(ctx),
    ),
    Dream.head("/", get_root(root_message)),
    Dream.get("/", get_root(root_message)),
    Dream.get(
      "/annotations/:container_id/:annotation_id",
      get_annotation(ctx),
    ),
    Dream.get("/annotations/:container_id", get_annotation_pages(ctx)),
    Dream.get("/annotations/:container_id/", get_annotation_collection(ctx)),
    Dream.post("/annotations/", post_container(ctx)),
    Dream.post("/annotations/:container_id/", post_annotation(ctx)),
    Dream.put(
      "/annotations/:container_id/:annotation_id",
      put_annotation(ctx),
    ),
    Dream.delete("/annotations/:container_id", delete_container(ctx)),
    Dream.delete(
      "/annotations/:container_id/:annotation_id",
      delete_annotation(ctx),
    ),
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
