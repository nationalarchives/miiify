module type S = Atdgen_runtime.Json_adapter.S

let wrap tag value = `List [ `String tag; value ]

let normalize_language = function
  | `String _ as s -> wrap "T1" s
  | `List _ as l -> wrap "T2" l
  | other -> other

let normalize_context = function
  | `String _ as s -> wrap "T1" s
  | `List _ as l -> wrap "T2" l
  | other -> other

let normalize_motivation = function
  | `String _ as s -> wrap "T1" s
  | `List _ as l -> wrap "T2" l
  | other -> other

let normalize_creator_item = function
  | `String _ as s -> wrap "T1" s
  | `Assoc _ as o -> wrap "T2" o
  | other -> other

let normalize_creator = function
  | `List xs ->
      let xs = List.map normalize_creator_item xs in
      wrap "T2" (`List xs)
  | other -> wrap "T1" (normalize_creator_item other)

let normalize_body_item = function
  | `Assoc fields ->
      (* Need to normalize language field inside body objects *)
      let normalized_fields = List.map
        (fun (k, v) ->
          if k = "language" then (k, normalize_language v) else (k, v))
        fields
      in
      wrap "T1" (`Assoc normalized_fields)
  | `String _ as s -> wrap "T2" s
  | other -> other

let normalize_body = function
  | `List xs ->
      let xs = List.map normalize_body_item xs in
      wrap "T2" (`List xs)
  | other -> wrap "T1" (normalize_body_item other)

let normalize_target_item = function
  | `String _ as s -> wrap "T1" s
  | `Assoc _ as o -> wrap "T2" o
  | other -> other

let normalize_target = function
  | `List xs ->
      let xs = List.map normalize_target_item xs in
      wrap "T2" (`List xs)
  | other -> wrap "T1" (normalize_target_item other)

let normalize_annotation = function
  | `Assoc fields ->
      `Assoc (List.map
        (fun (k, v) ->
          match k with
          | "@context" -> (k, normalize_context v)
          | "motivation" -> (k, normalize_motivation v)
          | "creator" -> (k, normalize_creator v)
          | "body" -> (k, normalize_body v)
          | "target" -> (k, normalize_target v)
          | _ -> (k, v))
        fields)
  | other -> other

let restore_language = function
  | `List [ `String "T1"; (`String _ as s) ] -> s
  | `List [ `String "T2"; (`List _ as l) ] -> l
  | other -> other

let restore_context = function
  | `List [ `String "T1"; (`String _ as s) ] -> s
  | `List [ `String "T2"; (`List _ as l) ] -> l
  | other -> other

let restore_motivation = function
  | `List [ `String "T1"; (`String _ as s) ] -> s
  | `List [ `String "T2"; (`List _ as l) ] -> l
  | other -> other

let restore_creator_item = function
  | `List [ `String "T1"; (`String _ as s) ] -> s
  | `List [ `String "T2"; (`Assoc _ as o) ] -> o
  | other -> other

let restore_creator = function
  | `List [ `String "T1"; v ] -> restore_creator_item v
  | `List [ `String "T2"; `List xs ] -> `List (List.map restore_creator_item xs)
  | other -> other

let restore_body_item = function
  | `List [ `String "T1"; `Assoc fields ] ->
      (* Need to restore language field inside body objects *)
      `Assoc (List.map
        (fun (k, v) ->
          if k = "language" then (k, restore_language v) else (k, v))
        fields)
  | `List [ `String "T2"; (`String _ as s) ] -> s
  | other -> other

let restore_body = function
  | `List [ `String "T1"; v ] -> restore_body_item v
  | `List [ `String "T2"; `List xs ] -> `List (List.map restore_body_item xs)
  | other -> other

let restore_target_item = function
  | `List [ `String "T1"; (`String _ as s) ] -> s
  | `List [ `String "T2"; (`Assoc _ as o) ] -> o
  | other -> other

let restore_target = function
  | `List [ `String "T1"; v ] -> restore_target_item v
  | `List [ `String "T2"; `List xs ] -> `List (List.map restore_target_item xs)
  | other -> other

let restore_annotation = function
  | `Assoc fields ->
      `Assoc (List.map
        (fun (k, v) ->
          match k with
          | "@context" -> (k, restore_context v)
          | "motivation" -> (k, restore_motivation v)
          | "creator" -> (k, restore_creator v)
          | "body" -> (k, restore_body v)
          | "target" -> (k, restore_target v)
          | _ -> (k, v))
        fields)
  | other -> other

let normalize = normalize_annotation
let restore = restore_annotation