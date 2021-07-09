type t;

let create: (~fname: string) => t;

let add: (~ctx: t, ~key: string, ~data: Ezjsonm.t) => Lwt.t(unit);

let get: (~ctx: t, ~key: string) => Lwt.t(Ezjsonm.t);