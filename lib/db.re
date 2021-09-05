open Lwt.Infix;

module Git_store_json_value = Irmin_unix.Git.FS.KV(Irmin.Contents.Json_value);
module Store = Git_store_json_value;
module Proj = Irmin.Json_tree(Store);

let info = message => Irmin_unix.info(~author="miiify.rocks", "%s", message);

type t = {db: Lwt.t(Store.t)};

let create = (~fname) => {
  let config = Irmin_git.config(~bare=true, fname);
  let repo = Store.Repo.v(config);
  let branch = repo >>= Store.master;
  {db: branch};
};

let add = (~ctx, ~key, ~json, ~message) => {
  let json = Ezjsonm.value(json);
  ctx.db
  >>= {
    branch => Proj.set(branch, key, json, ~info=info(message));
  };
};

let get = (~ctx, ~key) => {
  ctx.db
  >>= {
    branch =>
      Proj.get(branch, key) >|= (json => `O(Ezjsonm.get_dict(json)));
  };
};

let delete = (~ctx, ~key, ~message) => {
  ctx.db >>= (branch => Store.remove_exn(branch, key, ~info=info(message)));
};

let exists = (~ctx, ~key) => {
  ctx.db >>= (branch => Store.mem_tree(branch, key));
};

let get_collection = (~ctx, ~key, ~offset, ~length) => {
  ctx.db
  >>= {
    branch =>
      Store.get_tree(branch, key)
      >>= {
        tree =>
          Store.Tree.list(tree, [], ~offset, ~length)
          >>= Lwt_list.map_s(((k, _)) =>
                get(~ctx, ~key=List.append(key, [k]))
              )
          >|= Ezjsonm.list(x => x);
      };
  };
};

let count = (~ctx, ~key) => {
  ctx.db >>= (branch => Store.list(branch, key) >|= List.length);
};

let get_hash = (~ctx, ~key) => {
  ctx.db
  >>= (branch => Store.hash(branch, key))
  >|= (
    hash =>
      switch (hash) {
      | Some(hash) => Some(Store.Git.Hash.to_hex(hash));
      | None => None;
      }
  );
};

let compare_hash = (~ctx, ~key, ~hash) => {
  ctx.db
  >>= (branch => Store.hash(branch, key))
  >|= (
    hash' =>
      switch (hash') {
      | Some(hash') => Store.Git.Hash.to_hex(hash') == hash
      | None => false
      }
  );
};
