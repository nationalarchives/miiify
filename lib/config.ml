let create_config data = Config_j.config_of_string data

let parse ~data =
  match create_config data with
  | exception e -> Result.error (Printexc.to_string e)
  | config -> Result.ok config
