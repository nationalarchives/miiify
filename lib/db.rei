type t;

let create: (~fname: string) => t;

let add: (~ctx: t, ~key: list(string), ~json: Ezjsonm.t, ~message: string) => Lwt.t(unit);

let get: (~ctx: t, ~key: list(string)) => Lwt.t(Ezjsonm.t);

let delete: (~ctx: t, ~key: list(string), ~message: string) => Lwt.t(unit);

let exists: (~ctx: t, ~key: list(string)) => Lwt.t(bool);

let get_collection: (~ctx: t, ~key: list(string), ~offset: int, ~length: int) => Lwt.t(Ezjsonm.t);

let count: (~ctx: t, ~key: list(string)) => Lwt.t(int);