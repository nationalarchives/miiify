open Lwt.Infix;

type t = {page_limit: int};

let create = (~page_limit) => {
  {page_limit: page_limit};
};

let get_next_page = (id, last_page) =>
  if (last_page > 0) {
    id ++ "?page=1";
  } else {
    id ++ "?page=0";
  };

let gen_first = (id, last_page, collection) => {
  Ezjsonm.(
    dict([
      ("id", string(id ++ "?page=0")),
      ("type", string("AnnotationPage")),
      ("next", string(get_next_page(id, last_page))),
      ("items", value(collection)),
    ])
  );
};

let gen_last = (id, last_page) => {
  let suffix = Printf.sprintf("?page=%d", last_page);
  Ezjsonm.string(id ++ suffix);
};

let get_id = json => {
  Ezjsonm.(get_string(find(json, ["id"])));
};

let annotation_collection_response = (count, limit, main, collection) => {
  open Ezjsonm;
  let id = get_id(value(main));
  let total = int(count);
  let last_page = count / limit;
  let first = gen_first(id, last_page, collection);
  let last = gen_last(id, last_page);
  let json = update(value(main), ["total"], Some(total));
  let json = update(json, ["first"], Some(first));
  let json = update(json, ["last"], Some(last));
  `O(get_dict(json));
};

let annotation_collection = (~ctx, ~db, ~key, ~page) => {
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
          Db.get_collection(
            ~ctx=db,
            ~key=k,
            ~offset=page * limit,
            ~length=limit,
          )
          >|= (
            collection =>
              annotation_collection_response(count, limit, main, collection)
          )
      );
    }
  );
};
