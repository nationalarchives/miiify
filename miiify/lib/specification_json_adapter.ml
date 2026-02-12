module type S = Atdgen_runtime.Json_adapter.S

let is_tagged_variant_for tags = function
  | `List (`String tag :: _) -> List.mem tag tags
  | `String tag -> List.mem tag tags
  | _ -> false

let wrap tag value = `List [ `String tag; value ]

let map_assoc f = function
  | `Assoc fields -> `Assoc (List.map f fields)
  | other -> other

let rec normalize_language = function
  | v when is_tagged_variant_for [ "T1"; "T2" ] v -> v
  | `String _ as s -> wrap "T1" s
  | `List xs -> wrap "T2" (`List xs)
  | other -> other

and normalize_context = function
  | v when is_tagged_variant_for [ "T1"; "T2" ] v -> v
  | `String _ as s -> wrap "T1" s
  | `List xs -> wrap "T2" (`List xs)
  | other -> other

and normalize_motivation = function
  | v when is_tagged_variant_for [ "T1"; "T2" ] v -> v
  | `String _ as s -> wrap "T1" s
  | `List xs -> wrap "T2" (`List xs)
  | other -> other

and normalize_creator_item = function
  | v when is_tagged_variant_for [ "T1"; "T2" ] v -> v
  | `String _ as s -> wrap "T1" s
  | `Assoc _ as o -> wrap "T2" (normalize_creator_detail o)
  | other -> other

and normalize_creator_detail = function
  | `Assoc fields ->
      let fields =
        List.map
          (fun (k, v) ->
            match k with
            | "type" -> (k, v)
            | _ -> (k, normalize_any v))
          fields
      in
      `Assoc fields
  | other -> other

and normalize_creator = function
  | v when is_tagged_variant_for [ "T1"; "T2" ] v -> v
  | `List xs ->
      let xs = List.map normalize_creator_item xs in
      wrap "T2" (`List xs)
  | other -> wrap "T1" (normalize_creator_item other)

and normalize_body_simple = function
  | `Assoc fields ->
      let fields =
        List.map
          (fun (k, v) ->
            match k with
            | "language" -> (k, normalize_language v)
            | _ -> (k, normalize_any v))
          fields
      in
      `Assoc fields
  | other -> other

and normalize_body_item = function
  | v when is_tagged_variant_for [ "T1"; "T2" ] v -> v
  | `Assoc _ as o -> wrap "T1" (normalize_body_simple o)
  | `String _ as s -> wrap "T2" s
  | other -> other

and normalize_body = function
  | v when is_tagged_variant_for [ "T1"; "T2" ] v -> v
  | `List xs ->
      let xs = List.map normalize_body_item xs in
      wrap "T2" (`List xs)
  | other -> wrap "T1" (normalize_body_item other)

and normalize_target_item = function
  | v when is_tagged_variant_for [ "T1"; "T2" ] v -> v
  | `String _ as s -> wrap "T1" s
  | `Assoc _ as o -> wrap "T2" (normalize_any o)
  | other -> other

and normalize_target = function
  | v when is_tagged_variant_for [ "T1"; "T2" ] v -> v
  | `List xs ->
      let xs = List.map normalize_target_item xs in
      wrap "T2" (`List xs)
  | other -> wrap "T1" (normalize_target_item other)

and normalize_annotation = function
  | `Assoc fields ->
      let fields =
        List.map
          (fun (k, v) ->
            match k with
            | "@context" -> (k, normalize_context v)
            | "motivation" -> (k, normalize_motivation v)
            | "creator" -> (k, normalize_creator v)
            | "body" -> (k, normalize_body v)
            | "target" -> (k, normalize_target v)
            | _ -> (k, normalize_any v))
          fields
      in
      `Assoc fields
  | other -> other

and normalize_any = function
  | `Assoc _ as o -> normalize_annotation o |> map_assoc (fun kv -> kv)
  | `List xs -> `List (List.map normalize_any xs)
  | other -> other

let unwrap = function
  | `List [ `String _tag; v ] -> Some v
  | _ -> None

let rec restore_language = function
  | `List [ `String "T1"; (`String _ as s) ] -> s
  | `List [ `String "T2"; (`List _ as l) ] -> l
  | other -> other

and restore_context = function
  | `List [ `String "T1"; (`String _ as s) ] -> s
  | `List [ `String "T2"; (`List _ as l) ] -> l
  | other -> other

and restore_motivation = function
  | `List [ `String "T1"; (`String _ as s) ] -> s
  | `List [ `String "T2"; (`List _ as l) ] -> l
  | other -> other

and restore_creator_item = function
  | `List [ `String "T1"; (`String _ as s) ] -> s
  | `List [ `String "T2"; (`Assoc _ as o) ] -> restore_any o
  | other -> other

and restore_creator = function
  | `List [ `String "T1"; v ] -> restore_creator_item v
  | `List [ `String "T2"; `List xs ] -> `List (List.map restore_creator_item xs)
  | other -> other

and restore_body_item = function
  | `List [ `String "T1"; (`Assoc _ as o) ] ->
      (match o with
      | `Assoc fields ->
          `Assoc
            (List.map
               (fun (k, v) ->
                 match k with
                 | "language" -> (k, restore_language v)
                 | _ -> (k, restore_any v))
               fields)
      | _ -> o)
  | `List [ `String "T2"; (`String _ as s) ] -> s
  | other -> other

and restore_body = function
  | `List [ `String "T1"; v ] -> restore_body_item v
  | `List [ `String "T2"; `List xs ] -> `List (List.map restore_body_item xs)
  | other -> other

and restore_target_item = function
  | `List [ `String "T1"; (`String _ as s) ] -> s
  | `List [ `String "T2"; (`Assoc _ as o) ] -> restore_any o
  | other -> other

and restore_target = function
  | `List [ `String "T1"; v ] -> restore_target_item v
  | `List [ `String "T2"; `List xs ] -> `List (List.map restore_target_item xs)
  | other -> other

and restore_annotation = function
  | `Assoc fields ->
      `Assoc
        (List.map
           (fun (k, v) ->
             match k with
             | "@context" -> (k, restore_context v)
             | "motivation" -> (k, restore_motivation v)
             | "creator" -> (k, restore_creator v)
             | "body" -> (k, restore_body v)
             | "target" -> (k, restore_target v)
             | _ -> (k, restore_any v))
           fields)
  | other -> other

and restore_any = function
  | `Assoc _ as o -> restore_annotation o
  | `List xs -> `List (List.map restore_any xs)
  | other -> other

let normalize = normalize_annotation
let restore = restore_annotation

let () =
  ignore (unwrap : Yojson.Safe.t -> Yojson.Safe.t option)