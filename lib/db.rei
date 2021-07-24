type t;

let create: (~fname: string) => t;

let add: (~ctx: t, ~key: string, ~json: Ezjsonm.t, ~message: string) => Lwt.t(unit);

let get: (~ctx: t, ~key: string) => Lwt.t(Ezjsonm.t);

let delete: (~ctx: t, ~key: string, ~message: string) => Lwt.t(unit);

let exists: (~ctx: t, ~key: string) => Lwt.t(bool);