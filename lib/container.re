open Lwt.Infix;

type t = {page_limit: int};

let create = (~page_limit) => {
  {page_limit: page_limit};
};

let get_value = (term, json) => {
  Ezjsonm.(find_opt(value(json), [term]));
};

let gen_id = (id, page) => {
  open Ezjsonm;
  let suffix = Printf.sprintf("?page=%d", page);
  Some(string(id ++ suffix));
};

let gen_type_page = () => {
  Some(Ezjsonm.string("AnnotationPage"));
};

let gen_total = count => {
  Some(Ezjsonm.int(count));
};

let gen_part_of = (id, count, main) => {
  open Ezjsonm;
  let created = get_value("created", main);
  let label = get_value("label", main);
  let total = gen_total(count);
  let json = dict([]);
  let json = update(json, ["id"], id);
  let json = update(json, ["created"], created);
  let json = update(json, ["total"], total);
  let json = update(json, ["label"], label);
  Some(`O(get_dict(json)));
};

let gen_items = collection => {
  Some(Ezjsonm.value(collection));
};

let gen_start_index = (page, limit) => {
  let index = page * limit;
  Some(Ezjsonm.int(index));
};

let gen_next = (id, page, count, limit) => {
  let last_page = count / limit;
  if (page < last_page) {
    gen_id(id, page + 1);
  } else {
    None;
  };
};

let gen_prev = (id, page) =>
  if (page > 0) {
    gen_id(id, page - 1);
  } else {
    None;
  };

let get_string_value = (term, json) => {
  Ezjsonm.(get_string(Option.get(get_value(term, json))));
};

let annotation_page_response = (page, count, limit, main, collection) => {
  open Ezjsonm;
  let context = get_value("@context", main);
  let id_value = get_string_value("id", main);
  let id = gen_id(id_value, page);
  let type_page = gen_type_page();
  let part_of = gen_part_of(id, count, main);
  let start_index = gen_start_index(page, limit);
  let prev = gen_prev(id_value, page);
  let next = gen_next(id_value, page, count, limit);
  let items = gen_items(collection);
  let json = dict([]);
  let json = update(json, ["@context"], context);
  let json = update(json, ["id"], id);
  let json = update(json, ["type"], type_page);
  let json = update(json, ["partOf"], part_of);
  let json = update(json, ["startIndex"], start_index);
  let json = update(json, ["prev"], prev);
  let json = update(json, ["next"], next);
  let json = update(json, ["items"], items);
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
      >>= {
        count =>
          switch (count) {
          | _ when page < 0 => Lwt.return(None)
          | 0 when page > 0 => Lwt.return(None)
          | 0 =>
            // return an empty items array
            Lwt.return(
              Some(
                annotation_page_response(page, count, limit, main, `A([])),
              ),
            )
          | _ when page > count / limit => Lwt.return(None)
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
                  ),
                )
            )
          };
      };
    }
  );
};