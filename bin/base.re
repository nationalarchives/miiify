let root_message = "Welcome to miiify!";

let gen_uuid = () =>
  Uuidm.v4_gen(Random.State.make_self_init(), ()) |> Uuidm.to_string;

let get_timestamp = () => {
  let t = Ptime_clock.now();
  Ptime.to_rfc3339(t, ~tz_offset_s=0);
};

let get_id = request => {
  switch (Dream.header("Slug", request)) {
  | None => gen_uuid()
  | Some(slug) => slug
  };
};

let get_if_none_match = request => {
  Dream.header("If-None-Match", request);
};

let get_if_match = request => {
  Dream.header("If-Match", request);
};

let get_host = request => {
  Option.get(Dream.header("Host", request));
};

let key_to_string = key => {
  List.fold_left((x, y) => x ++ "/" ++ y, "", key);
};

let get_page = request => {
  switch (Dream.query("page", request)) {
  | None => 0
  | Some(page) =>
    switch (int_of_string_opt(page)) {
    | None => 0
    | Some(value) => value
    }
  };
};

let process_representation = prefer => {
  let lis = String.split_on_char(' ', prefer);
  List.map(x => String.split_on_char('#', x), lis);
};

let strip_last_char = str =>
  if (str == "") {
    "";
  } else {
    String.sub(str, 0, String.length(str) - 1);
  };

let get_prefer = request => {
  switch (Dream.header("prefer", request)) {
  | None => "PreferContainedDescriptions"
  | Some(prefer) =>
    // we will just use the first preference if multiple exist
    switch (process_representation(prefer)) {
    // the last char is the end quote
    | [[_, x], ..._] => strip_last_char(x)
    | _ => "PreferContainedDescriptions"
    }
  };
};

let make_error = (status, reason) => {
  open Ezjsonm;
  let code = Dream.status_to_int(status);
  let json = dict([("code", int(code)), ("reason", string(reason))]);
  to_string(json);
};

let error_response = (status, reason) => {
  let resp = make_error(status, reason);
  Dream.json(~status, resp);
};

let html_headers = body => {
  let content_length = Printf.sprintf("%d", String.length(body));
  let content_type = ("Content-Type", "text/html; charset=utf-8");
  [content_type, ("Content-length", content_length)];
};

let options_headers = lis => {
  let meths = List.fold_left((x, y) => x ++ y ++ " ", "", lis);
  let allow = ("Allow", String.trim(meths));
  [allow];
};

let options_response = options => {
  Dream.empty(~headers=options_headers(options), `No_Content);
};

let html_response = body => {
  Dream.respond(~headers=html_headers(body), body);
};

let html_empty_response = body => {
  Dream.empty(~headers=html_headers(body), `OK);
};

let gen_link_header_annotation = () => {
  Some([("Link", "<http://www.w3.org/ns/ldp#Resource>; rel=\"type\"")]);
};

let gen_link_header_annotation_page = () => {
  Some([("Link", "<http://www.w3.org/ns/oa#AnnotationPage>; rel=\"type\"")]);
};

let gen_link_header_basic_container = () => {
  Some([
    ("Link", "<http://www.w3.org/ns/ldp#BasicContainer>; rel=\"type\""),
    ("Link", "<http://www.w3.org/ns/oa#AnnotationCollection>; rel=\"type\""),
    (
      "Link",
      "<http://www.w3.org/TR/annotation-protocol/>; \"http://www.w3.org/ns/ldp#constrainedBy\"",
    ),
  ]);
};

let gen_link_headers = body => {
  Ezjsonm.(
    switch (find_opt(body, ["type"])) {
    | Some(`String("Annotation")) => gen_link_header_annotation()
    | Some(`String("AnnotationPage")) => gen_link_header_annotation_page()
    | Some(
        `A([`String("BasicContainer"), `String("AnnotationCollection")]),
      ) =>
      gen_link_header_basic_container()
    | Some(
        `A([`String("AnnotationCollection"), `String("BasicContainer")]),
      ) =>
      gen_link_header_basic_container()
    | _ => None
    }
  );
};

let json_headers = (content, link, etag) => {
  let content_length = (
    "Content-length",
    Printf.sprintf("%d", String.length(content)),
  );
  let content_type = (
    "Content-Type",
    "application/ld+json; profile=\"http://www.w3.org/ns/anno.jsonld\"",
  );
  let header =
    switch (link) {
    | None => [content_type, content_length]
    | Some(link) => List.append([content_type, content_length], link)
    };
  switch (etag) {
  | None => header
  | Some(etag) => List.cons(("ETag", "\"" ++ etag ++ "\""), header)
  };
};

let json_body_response = (~body, ~etag, ~code=200, ()) => {
  let link = gen_link_headers(body);
  let resp = Ezjsonm.value_to_string(body);
  Dream.respond(~headers=json_headers(resp, link, etag), resp, ~code);
};

let json_empty_response = (~body, ~etag) => {
  let link = gen_link_headers(body);
  let resp = Ezjsonm.value_to_string(body);
  Dream.empty(~headers=json_headers(resp, link, etag), `OK);
};

let json_response = (~request, ~body, ~etag=None, ()) => {
  switch (Dream.method(request)) {
  | `HEAD => json_empty_response(~body, ~etag)
  | `GET => json_body_response(~body, ~etag, ())
  | `PUT => json_body_response(~body, ~etag, ())
  | `POST => json_body_response(~body, ~etag, ~code=201, ())
  | _ => error_response(`Method_Not_Allowed, "unsupported method")
  };
};
