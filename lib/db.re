open Lwt.Infix;

module Git_store_json_value = Irmin_unix.Git.FS.KV(Irmin.Contents.Json_value);
module Store = Git_store_json_value;
module Proj = Irmin.Json_tree(Store);

let info = message => Irmin_unix.info(~author="miiify.rocks", "%s", message);

type t = {db: Lwt.t(Store.t)};

let create = (~fname) => {
  let config = Irmin_git.config(~bare=false, fname);
  let repo = Store.Repo.v(config);
  let branch = repo >>= Store.master;
  {db: branch};
};

let add = (~ctx, ~key, ~data) => {
  let json = Ezjsonm.value(data);
  ctx.db
  >>= {
    branch => Proj.set(branch, [key], json, ~info=info("adding data"));
  };
};

let get = (~ctx, ~key) => {
  ctx.db
  >>= {
    branch =>
      Proj.get(branch, [key]) >|= (json => `O(Ezjsonm.get_dict(json)))
  };
};
