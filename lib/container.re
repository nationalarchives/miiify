open Lwt.Infix;

type t = {
  page_limit: int,
  mutable representation: string,
};

let create = (~page_limit, ~representation) => {
  {page_limit, representation};
};

let get_representation = (~ctx) => {
  ctx.representation;
};

let set_representation = (~ctx, ~representation) => {
  ctx.representation = representation;
};

let get_value = (term, json) => {
  Ezjsonm.(find_opt(json, [term]));
};

let gen_id_page = (id, page) => {
  open Ezjsonm;
  let suffix = Printf.sprintf("?page=%d", page);
  Some(string(id ++ suffix));
};

let gen_id_collection = id => {
  Ezjsonm.(Some(string(id ++ "/")));
};

let gen_type_page = () => {
  Some(Ezjsonm.string("AnnotationPage"));
};

let gen_type_collection = () => {
  Some(Ezjsonm.strings(["BasicContainer", "AnnotationCollection"]));
};

let gen_total = count => {
  Some(Ezjsonm.int(count));
};

let gen_part_of = (id_value, count, main) => {
  open Ezjsonm;
  let id = gen_id_collection(id_value);
  let created = get_value("created", main);
  let modified = get_value("modified", main);
  let label = get_value("label", main);
  let total = gen_total(count);
  let json = dict([]);
  let json = update(json, ["id"], id);
  let json = update(json, ["created"], created);
  let json = update(json, ["modified"], modified);
  let json = update(json, ["total"], total);
  let json = update(json, ["label"], label);
  Some(json);
};

let gen_prefer_contained_iris = collection => {
  Ezjsonm.(
    Some(list(x => x, get_list(x => find(x, ["id"]), collection)))
  );
};

let gen_prefer_contained_descriptions = collection => {
  Some(collection)
}

let gen_items = (collection, representation) => {
  switch (representation) {
  | "PreferContainedDescriptions" => gen_prefer_contained_descriptions(collection)
  | "PreferContainedIRIs" => gen_prefer_contained_iris(collection)
  | "PreferMinimalContainer" => None
  | _ => gen_prefer_contained_descriptions(collection)
  };
};

let gen_start_index = (page, limit) => {
  let index = page * limit;
  Some(Ezjsonm.int(index));
};

let gen_next = (id, page, count, limit) => {
  let last_page = count / limit;
  if (page < last_page) {
    gen_id_page(id, page + 1);
  } else {
    None;
  };
};

let gen_prev = (id, page) =>
  if (page > 0) {
    gen_id_page(id, page - 1);
  } else {
    None;
  };

let gen_last = (id, count, limit) => {
  let last_page = count / limit;
  if (last_page > 0) {
    gen_id_page(id, last_page);
  } else {
    None;
  };
};

let get_string_value = (term, json) => {
  Ezjsonm.(get_string(Option.get(get_value(term, json))));
};

let annotation_page_response =
    (page, count, limit, main, collection, representation) => {
  open Ezjsonm;
  let context = get_value("@context", main);
  let id_value = get_string_value("id", main);
  let id = gen_id_page(id_value, page);
  let type_page = gen_type_page();
  let part_of = gen_part_of(id_value, count, main);
  let start_index = gen_start_index(page, limit);
  let prev = gen_prev(id_value, page);
  let next = gen_next(id_value, page, count, limit);
  let items = gen_items(collection, representation);
  let json = dict([]);
  let json = update(json, ["@context"], context);
  let json = update(json, ["id"], id);
  let json = update(json, ["type"], type_page);
  let json = update(json, ["partOf"], part_of);
  let json = update(json, ["startIndex"], start_index);
  let json = update(json, ["prev"], prev);
  let json = update(json, ["next"], next);
  let json = update(json, ["items"], items);
  json;
};

let annotation_page = (~ctx, ~db, ~key, ~page) => {
  // get main data
  Db.get(~ctx=db, ~key)
  >>= (
    main => {
      let limit = ctx.page_limit;
      let representation = ctx.representation;
      // swap "main" for "collection"
      let k = List.cons(List.hd(key), ["collection"]);
      Db.count(~ctx=db, ~key=k)
      >>= {
        count =>
          switch (count) {
          | _ when page < 0 => Lwt.return(None)
          | _ when page > count / limit => Lwt.return(None)
          | 0 when page > 0 => Lwt.return(None)
          | 0 =>
            // return an empty items array
            Lwt.return(
              Some(
                annotation_page_response(
                  page,
                  count,
                  limit,
                  main,
                  `A([]),
                  representation,
                ),
              ),
            )
          | _ =>
            Db.get_collection(
              ~ctx=db,
              ~key=k,
              ~offset=page * limit,
              ~length=limit,
            )
            >|= (
              collection =>
                Some(
                  annotation_page_response(
                    page,
                    count,
                    limit,
                    main,
                    collection,
                    representation,
                  ),
                )
            )
          };
      };
    }
  );
};

let gen_first = (id_value, count, limit, collection, representation) => {
  open Ezjsonm;
  let id = gen_id_page(id_value, 0);
  let type_page = gen_type_page();
  let next = gen_next(id_value, 0, count, limit);
  let items = gen_items(collection, representation);
  let json = dict([]);
  let json = update(json, ["id"], id);
  let json = update(json, ["type"], type_page);
  let json = update(json, ["items"], items);
  let json = update(json, ["next"], next);
  Some(json);
};

let annotation_collection_response =
    (count, limit, main, collection, representation) => {
  open Ezjsonm;
  let context = get_value("@context", main);
  let id_value = get_string_value("id", main);
  let id = gen_id_collection(id_value);
  let type_collection = gen_type_collection();
  let label = get_value("label", main);
  let first = gen_first(id_value, count, limit, collection, representation);
  let created = get_value("created", main);
  let modified = get_value("modified", main);
  let total = gen_total(count);
  let last = gen_last(id_value, count, limit);
  let json = dict([]);
  let json = update(json, ["@context"], context);
  let json = update(json, ["id"], id);
  let json = update(json, ["type"], type_collection);
  let json = update(json, ["label"], label);
  let json = update(json, ["created"], created);
  let json = update(json, ["modified"], modified);
  let json = update(json, ["total"], total);
  let json = update(json, ["first"], first);
  let json = update(json, ["last"], last);
  json;
};

let annotation_collection = (~ctx, ~db, ~key) => {
  // get main data
  Db.get(~ctx=db, ~key)
  >>= (
    main => {
      let limit = ctx.page_limit;
      let representation = ctx.representation;
      // swap "main" for "collection"
      let k = List.cons(List.hd(key), ["collection"]);
      Db.count(~ctx=db, ~key=k)
      >>= {
        count =>
          switch (count) {
          | 0 =>
            // return an empty items array
            Lwt.return(
              annotation_collection_response(
                count,
                limit,
                main,
                `A([]),
                representation,
              ),
            )
          | _ =>
            Db.get_collection(~ctx=db, ~key=k, ~offset=0, ~length=limit)
            >|= (
              collection =>
                annotation_collection_response(
                  count,
                  limit,
                  main,
                  collection,
                  representation,
                )
            )
          };
      };
    }
  );
};