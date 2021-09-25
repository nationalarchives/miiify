
let create_config = (data) => {
  Config_j.config_of_string(data);
}

let parse = (~data) => {
  switch(create_config(data)) {
    | exception (e) => Result.error(Printexc.to_string(e));
    | config => Result.ok(config);
  }
}