open Lwt.Infix;

let embedded_response = (main, collection) => {
  Ezjsonm.(
    `O(
      get_dict(update(value(main), ["items"], Some(value(collection)))),
    )
  );
};

let with_annotations = (~ctx, ~key, ~offset, ~length) => {
  // get main data
  Db.get(~ctx, ~key)
  >>= (
    main => {
      // swap "main" for "collection"
      let k = List.cons(List.hd(key), ["collection"]);
      Db.get_collection(~ctx, ~key=k, ~offset, ~length)
      >|= (collection => embedded_response(main, collection));
    }
  );
};
