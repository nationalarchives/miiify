open Lwt.Infix;

type t = {page_limit: int};

let create = (~page_limit) => {
  {page_limit: page_limit};
};

let gen_id  = (id, page) => {
  open Ezjsonm;
  let suffix = Printf.sprintf("?page=%d", page);
  string(id ++ suffix);
};

let gen_type_page = () => {
  Ezjsonm.string("AnnotationPage");
};

let gen_part_of = (id, count, main) => {
  Ezjsonm.(
    switch (find_opt(value(main), ["label"])) {
    | None => dict([("id", string(id)), ("total", int(count))])
    | Some(label) =>
      dict([("id", string(id)), ("label", label), ("total", int(count))])
    }
  );
};

let gen_items = collection => {
  Ezjsonm.value(collection);
};

let gen_start_index = (page, limit) => {
  let index = page * limit;
  Ezjsonm.int(index);
};

let gen_next = (id, page, count, limit) => {
  let last_page = count / limit;
  if (page < last_page) {
    Some(gen_id(id, page+1))
  } else {
    None;
  };
};

let gen_prev = (id, page) => {
  if (page > 0) {
    Some(gen_id(id, page-1))
  } else {
    None;
  };
};


let get_value = (term, json) => {
  Ezjsonm.(find(value(json), [term]));
};

let get_string_value = (term, json) => {
  Ezjsonm.(get_string(get_value(term, json)));
};

let annotation_page_response = (page, count, limit, main, collection) => {
  open Ezjsonm;
  let context = get_value("@context", main);
  let id_value = get_string_value("id", main);
  let id = gen_id(id_value, page);
  let type_page = gen_type_page();
  let part_of = gen_part_of(id_value, count, main);
  let start_index = gen_start_index(page, limit);
  let prev = gen_prev(id_value, page);
  let next = gen_next(id_value, page, count, limit);
  let items = gen_items(collection);
  let json = dict([]);
  let json = update(json, ["@context"], Some(context));
  let json = update(json, ["id"], Some(id));
  let json = update(json, ["type"], Some(type_page));
  let json = update(json, ["partOf"], Some(part_of));
  let json = update(json, ["startIndex"], Some(start_index));
  let json = update(json, ["prev"], prev);
  let json = update(json, ["next"], next);
  let json = update(json, ["items"], Some(items));
  `O(get_dict(json));
};



let annotation_page = (~ctx, ~db, ~key, ~page) => {
  // get main data
  Db.get(~ctx=db, ~key)
  >>= (
    main => {
      let limit = ctx.page_limit;
      // swap "main" for "collection"
      let k = List.cons(List.hd(key), ["collection"]);
      Db.count(~ctx=db, ~key=k)
      >>= (
        count =>
          if (count == 0) {
            // return an empty items array
            Lwt.return(
              annotation_page_response(page, count, limit, main, `A([])),
            );
          } else {
            Db.get_collection(
              ~ctx=db,
              ~key=k,
              ~offset=page * limit,
              ~length=limit,
            )
            >|= (
              collection =>
                annotation_page_response(page, count, limit, main, collection)
            );
          }
      );
    }
  );
};