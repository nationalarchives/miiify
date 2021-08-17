type t;

let create: (~page_limit: int) => t;

let annotation_page: (~ctx: t, ~db: Db.t, ~key: list(string), ~page: int) => Lwt.t(Ezjsonm.t);
