open Alcotest

(* Test the JSON adapter normalize and restore functions *)

let test_context_string () =
  let json = `Assoc [("@context", `String "http://www.w3.org/ns/anno.jsonld")] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "context string round-trip" true (json = restored)

let test_context_list () =
  let json = `Assoc [("@context", `List [`String "http://www.w3.org/ns/anno.jsonld"; `String "http://example.org"])] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "context list round-trip" true (json = restored)

let test_motivation_string () =
  let json = `Assoc [("type", `String "Annotation"); ("motivation", `String "commenting")] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "motivation string round-trip" true (json = restored)

let test_motivation_list () =
  let json = `Assoc [("type", `String "Annotation"); ("motivation", `List [`String "commenting"; `String "tagging"])] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "motivation list round-trip" true (json = restored)

let test_language_string () =
  let json = `Assoc [
    ("type", `String "Annotation");
    ("body", `Assoc [
      ("type", `String "TextualBody");
      ("value", `String "Hello");
      ("language", `String "en")
    ])
  ] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "language string round-trip" true (json = restored)

let test_language_list () =
  let json = `Assoc [
    ("type", `String "Annotation");
    ("body", `Assoc [
      ("type", `String "TextualBody");
      ("value", `String "Hello");
      ("language", `List [`String "en"; `String "fr"])
    ])
  ] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "language list round-trip" true (json = restored)

let test_body_simple_object () =
  let json = `Assoc [
    ("type", `String "Annotation");
    ("body", `Assoc [
      ("type", `String "TextualBody");
      ("value", `String "Comment")
    ])
  ] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "body simple object round-trip" true (json = restored)

let test_body_string () =
  let json = `Assoc [
    ("type", `String "Annotation");
    ("body", `String "Simple text body")
  ] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "body string round-trip" true (json = restored)

let test_body_list_mixed () =
  let json = `Assoc [
    ("type", `String "Annotation");
    ("body", `List [
      `Assoc [("type", `String "TextualBody"); ("value", `String "First")];
      `String "Second body as string";
      `Assoc [("type", `String "TextualBody"); ("value", `String "Third")]
    ])
  ] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "body list mixed round-trip" true (json = restored)

let test_target_string () =
  let json = `Assoc [
    ("type", `String "Annotation");
    ("target", `String "https://example.com/canvas/1")
  ] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "target string round-trip" true (json = restored)

let test_target_object () =
  let json = `Assoc [
    ("type", `String "Annotation");
    ("target", `Assoc [
      ("id", `String "https://example.com/canvas/1");
      ("type", `String "Canvas")
    ])
  ] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "target object round-trip" true (json = restored)

let test_target_list_mixed () =
  let json = `Assoc [
    ("type", `String "Annotation");
    ("target", `List [
      `String "https://example.com/canvas/1";
      `Assoc [("id", `String "https://example.com/canvas/2")];
      `String "https://example.com/canvas/3"
    ])
  ] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "target list mixed round-trip" true (json = restored)

let test_creator_string () =
  let json = `Assoc [
    ("type", `String "Annotation");
    ("creator", `String "mailto:user@example.com")
  ] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "creator string round-trip" true (json = restored)

let test_creator_object () =
  let json = `Assoc [
    ("type", `String "Annotation");
    ("creator", `Assoc [
      ("id", `String "https://example.com/user/1");
      ("type", `String "Person");
      ("name", `String "John Doe")
    ])
  ] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "creator object round-trip" true (json = restored)

let test_creator_list_mixed () =
  let json = `Assoc [
    ("type", `String "Annotation");
    ("creator", `List [
      `String "mailto:user1@example.com";
      `Assoc [("id", `String "https://example.com/user/2"); ("name", `String "Jane")];
      `String "mailto:user3@example.com"
    ])
  ] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "creator list mixed round-trip" true (json = restored)

let test_complex_annotation () =
  let json = `Assoc [
    ("@context", `List [`String "http://www.w3.org/ns/anno.jsonld"; `String "http://example.org"]);
    ("type", `String "Annotation");
    ("motivation", `List [`String "commenting"; `String "tagging"]);
    ("creator", `List [
      `String "mailto:user@example.com";
      `Assoc [("type", `String "Person"); ("name", `String "Annotator")]
    ]);
    ("body", `List [
      `Assoc [
        ("type", `String "TextualBody");
        ("value", `String "First comment");
        ("language", `List [`String "en"; `String "en-US"])
      ];
      `String "Simple body text";
      `Assoc [
        ("type", `String "TextualBody");
        ("value", `String "Deuxième commentaire");
        ("language", `String "fr")
      ]
    ]);
    ("target", `List [
      `String "https://example.com/canvas/1#xywh=100,100,200,50";
      `Assoc [
        ("id", `String "https://example.com/canvas/2");
        ("type", `String "Canvas");
        ("selector", `Assoc [("type", `String "FragmentSelector"); ("value", `String "xywh=0,0,100,100")])
      ]
    ])
  ] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "complex annotation round-trip" true (json = restored)

let test_preserves_other_fields () =
  let json = `Assoc [
    ("type", `String "Annotation");
    ("id", `String "https://example.com/anno/1");
    ("created", `String "2026-02-17T12:00:00Z");
    ("modified", `String "2026-02-17T13:00:00Z");
    ("motivation", `String "commenting");
    ("body", `Assoc [
      ("type", `String "TextualBody");
      ("value", `String "Test");
      ("format", `String "text/plain");
      ("purpose", `String "commenting")
    ]);
    ("target", `String "https://example.com/target")
  ] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "preserves other fields" true (json = restored)

let test_atd_validation_with_variants () =
  (* Test that normalized JSON validates against ATD schema *)
  let json_str = {|{
    "type": "Annotation",
    "motivation": ["commenting", "tagging"],
    "body": [
      {"type": "TextualBody", "value": "Comment", "language": ["en", "fr"]},
      "Simple text"
    ],
    "target": [
      "https://example.com/canvas/1",
      {"id": "https://example.com/canvas/2"}
    ],
    "creator": [
      "mailto:user@example.com",
      {"type": "Person", "name": "John"}
    ]
  }|} in
  match Miiify.Specification_j.specification_of_string json_str with
  | _spec -> () (* Success *)
  | exception e -> 
      Alcotest.fail ("ATD validation failed: " ^ Printexc.to_string e)

let test_atd_validation_single_values () =
  (* Test that single values (not lists) also validate *)
  let json_str = {|{
    "type": "Annotation",
    "motivation": "commenting",
    "body": {"type": "TextualBody", "value": "Comment", "language": "en"},
    "target": "https://example.com/canvas/1",
    "creator": "mailto:user@example.com"
  }|} in
  match Miiify.Specification_j.specification_of_string json_str with
  | _spec -> () (* Success *)
  | exception e ->
      Alcotest.fail ("ATD validation failed: " ^ Printexc.to_string e)

let test_invalid_motivation_number () =
  (* motivation as number should pass through normalize but fail ATD validation *)
  let json = `Assoc [("type", `String "Annotation"); ("motivation", `Int 123)] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  (* Check that the invalid value passed through unchanged *)
  let motivation = match normalized with
    | `Assoc fields -> List.assoc "motivation" fields
    | _ -> `Null
  in
  Alcotest.(check bool) "invalid motivation passes through" true (motivation = `Int 123);
  
  (* Now verify ATD validation catches it *)
  let json_str = {|{"type": "Annotation", "motivation": 123}|} in
  match Miiify.Specification_j.specification_of_string json_str with
  | _spec -> Alcotest.fail "Expected validation to fail for number motivation"
  | exception _ -> () (* Expected to fail *)

let test_invalid_language_boolean () =
  (* language as boolean should pass through normalize but fail ATD validation *)
  let json = `Assoc [
    ("type", `String "Annotation");
    ("body", `Assoc [
      ("type", `String "TextualBody");
      ("value", `String "Test");
      ("language", `Bool true)
    ])
  ] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  (* The boolean should pass through normalize/restore unchanged *)
  Alcotest.(check bool) "invalid language passes through" true (json = restored);
  
  (* Verify ATD validation catches it *)
  let json_str = {|{"type": "Annotation", "body": {"type": "TextualBody", "value": "Test", "language": true}}|} in
  match Miiify.Specification_j.specification_of_string json_str with
  | _spec -> Alcotest.fail "Expected validation to fail for boolean language"
  | exception _ -> () (* Expected to fail *)

let test_invalid_target_number () =
  let json = `Assoc [("type", `String "Annotation"); ("target", `Int 999)] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "invalid target passes through" true (json = restored)

let test_invalid_body_null () =
  let json = `Assoc [("type", `String "Annotation"); ("body", `Null)] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "null body passes through" true (json = restored)

let test_invalid_creator_number () =
  let json = `Assoc [("type", `String "Annotation"); ("creator", `Float 3.14)] in
  let normalized = Miiify.Specification_json_adapter.normalize json in
  let restored = Miiify.Specification_json_adapter.restore normalized in
  Alcotest.(check bool) "invalid creator passes through" true (json = restored)

let () =
  run "JSON Adapter Tests" [
    ("Context", [
      test_case "string" `Quick test_context_string;
      test_case "list" `Quick test_context_list;
    ]);
    ("Motivation", [
      test_case "string" `Quick test_motivation_string;
      test_case "list" `Quick test_motivation_list;
    ]);
    ("Language", [
      test_case "string in body" `Quick test_language_string;
      test_case "list in body" `Quick test_language_list;
    ]);
    ("Body", [
      test_case "simple object" `Quick test_body_simple_object;
      test_case "string" `Quick test_body_string;
      test_case "list mixed" `Quick test_body_list_mixed;
    ]);
    ("Target", [
      test_case "string" `Quick test_target_string;
      test_case "object" `Quick test_target_object;
      test_case "list mixed" `Quick test_target_list_mixed;
    ]);
    ("Creator", [
      test_case "string" `Quick test_creator_string;
      test_case "object" `Quick test_creator_object;
      test_case "list mixed" `Quick test_creator_list_mixed;
    ]);
    ("Complex", [
      test_case "full annotation with all variants" `Quick test_complex_annotation;
      test_case "preserves other fields" `Quick test_preserves_other_fields;
    ]);
    ("ATD Validation", [
      test_case "validates with variant lists" `Quick test_atd_validation_with_variants;
      test_case "validates with single values" `Quick test_atd_validation_single_values;
    ]);
    ("Invalid Input Handling", [
      test_case "invalid motivation number" `Quick test_invalid_motivation_number;
      test_case "invalid language boolean" `Quick test_invalid_language_boolean;
      test_case "invalid target number" `Quick test_invalid_target_number;
      test_case "invalid body null" `Quick test_invalid_body_null;
      test_case "invalid creator float" `Quick test_invalid_creator_number;
    ]);
  ]
