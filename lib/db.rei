type t;

let create: (~fname: string, ~author: string) => t;

let add: (~ctx: t, ~key: list(string), ~json: Ezjsonm.value, ~message: string) => Lwt.t(unit);

let get: (~ctx: t, ~key: list(string)) => Lwt.t(Ezjsonm.value);

let delete: (~ctx: t, ~key: list(string), ~message: string) => Lwt.t(unit);

let exists: (~ctx: t, ~key: list(string)) => Lwt.t(bool);

let get_collection: (~ctx: t, ~key: list(string), ~offset: int, ~length: int) => Lwt.t(Ezjsonm.value);

let count: (~ctx: t, ~key: list(string)) => Lwt.t(int);

let get_hash: (~ctx: t, ~key: list(string)) => Lwt.t(option(string));
