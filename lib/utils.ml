let get_timestamp () =
  let t = Ptime_clock.now () in
  Ptime.to_rfc3339 t ~tz_offset_s:0

let read_file filename =
  let ch = open_in filename in
  let s = really_input_string ch (in_channel_length ch) in
  close_in ch;
  s

let key_to_string key = List.fold_left (fun x y -> x ^ "/" ^ y) "" key
