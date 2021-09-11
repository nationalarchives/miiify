type t;

let create: (~page_limit: int, ~representation: string) => t;

let annotation_page: (~ctx: t, ~db: Db.t, ~key: list(string), ~page: int) => Lwt.t(option(Ezjsonm.value));

let annotation_collection: (~ctx: t, ~db: Db.t, ~key: list(string)) => Lwt.t(Ezjsonm.value);

let get_representation: (~ctx: t) => string;
let set_representation: (~ctx: t, ~representation: string) => unit;
