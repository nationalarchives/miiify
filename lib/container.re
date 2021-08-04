

let with_annotations = (~ctx, ~key, ~offset, ~length) => {
  Db.get_collection(~ctx, ~key, ~offset, ~length)
}