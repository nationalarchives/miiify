let validate ~data ~enabled =
  if enabled then
    try
      let spec = Specification_j.specification_of_string data in
      Specification_v.validate_specification [] spec |> function
      | None -> Result.ok ()
      | Some e ->
          Result.error (Atdgen_runtime.Util.Validation.string_of_error e)
    with exc -> Result.error (Printexc.to_string exc)
  else Result.ok ()
