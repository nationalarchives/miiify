

let create: (~fname: string) => unit;

let add: (~key: string, ~data: Ezjsonm.t) => Lwt.t(unit);

let get: (~key: string) => Lwt.t(Ezjsonm.t);