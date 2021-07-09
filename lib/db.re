
type t = {
  fname: string,
}

let create = (~fname) => {
  { fname: fname};
};

let add = (~ctx, ~key, ~data) => {
  Dream.log("the database name is %s", ctx.fname);
  Lwt.return_unit;
}

let get = (~ctx, ~key) => {
  Ezjsonm.dict([]) |> Lwt.return;
}


