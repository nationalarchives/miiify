open Lwt.Syntax

module Header : sig
  val jsonld_content_type : (string * string) list
  val manifest_content_type : (string * string) list
  val collection_link : (string * string) list
  val page_link : (string * string) list
  val annotation_link : (string * string) list
  val options_status : (string * string) list
  val options_version : (string * string) list
  val options_container : (string * string) list
  val options_annotations : (string * string) list
end = struct
  let jsonld_content_type =
    [
      ( "Content-Type",
        "application/ld+json; profile=\"http://www.w3.org/ns/anno.jsonld\"" );
    ]

  let manifest_content_type =
    [
      ( "Content-Type",
        "application/ld+json; \
         profile=\"http://iiif.io/api/presentation/3/context.json\"" );
    ]

  let collection_link =
    [
      ("Link", "<http://www.w3.org/ns/ldp#BasicContainer>; rel=\"type\"");
      ( "Link",
        "<http://www.w3.org/TR/annotation-protocol/>; \
         \"http://www.w3.org/ns/ldp#constrainedBy\"" );
    ]

  let page_link =
    [ ("Link", "<http://www.w3.org/ns/oa#AnnotationPage>; rel=\"type\"") ]

  let annotation_link =
    [ ("Link", "<http://www.w3.org/ns/ldp#Resource>; rel=\"type\"") ]

  let options_status = [ ("Allow", "OPTIONS, HEAD, GET") ]
  let options_version = [ ("Allow", "OPTIONS, HEAD, GET") ]
  let options_container = [ ("Allow", "OPTIONS, HEAD, GET, POST, PUT, DELETE") ]
  let options_annotations = [ ("Allow", "OPTIONS, HEAD, GET, POST") ]
end

let bad_request message = Dream.html ~status:`Bad_Request message
let not_found message = Dream.html ~status:`Not_Found message
let not_implemented message = Dream.html ~status:`Not_Implemented message
let not_modified message = Dream.html ~status:`Not_Modified message
let no_content () = Dream.empty `No_Content

let status message =
  Dream.html ~headers:Header.options_status ~status:`OK message

let options_status = Dream.empty ~headers:Header.options_status `OK

let version message =
  Dream.html ~headers:Header.options_version ~status:`OK message

let options_version = Dream.empty ~headers:Header.options_version `OK

let precondition_failed message =
  Dream.html ~status:`Precondition_Failed message

let options_container = Dream.empty ~headers:Header.options_container `OK

let get_container ~hash body =
  let open Header in
  let etag = [ ("ETag", "\"" ^ hash ^ "\"") ] in
  let headers = jsonld_content_type @ etag @ options_container in
  Dream.respond ~status:`OK ~headers body

let create_container body =
  let open Header in
  let headers = collection_link @ jsonld_content_type @ options_container in
  Dream.respond ~status:`Created ~headers body

let update_container body =
  let open Header in
  let headers = collection_link @ jsonld_content_type @ options_container in
  Dream.respond ~status:`OK ~headers body

let delete_container () = 
  let open Header in
  let headers = options_container in
  Dream.empty ~headers `No_Content

let create_annotation body =
  let open Header in
  let headers = jsonld_content_type in
  Dream.respond ~status:`Created ~headers body

let update_annotation body =
  let open Header in
  let headers = jsonld_content_type in
  Dream.respond ~status:`OK ~headers body

let delete_annotation = no_content

let options_annotations = Dream.empty ~headers:Header.options_annotations `OK

let get_collection ~hash body =
  let open Header in
  let etag = [ ("ETag", "\"" ^ hash ^ "\"") ] in
  let headers = collection_link @ jsonld_content_type @ etag @ options_annotations in
  Dream.respond ~status:`OK ~headers body

let get_page ~hash body =
  let open Header in
  let etag = [ ("ETag", "\"" ^ hash ^ "\"") ] in
  let headers = page_link @ jsonld_content_type @ etag @ options_annotations in
  Dream.respond ~status:`OK ~headers body

let get_annotation ~hash body =
  let open Header in
  let etag = [ ("ETag", "\"" ^ hash ^ "\"") ] in
  let headers = annotation_link @ jsonld_content_type @ etag in
  Dream.respond ~status:`OK ~headers body

let prefer_contained_descriptions response = response

let prefer_contained_iris _ =
  not_implemented "Please raise an issue if you would like this feature"

let prefer_minimal_container _ =
  not_implemented "Please raise an issue if you would like this feature"

let create_manifest body =
  let open Header in
  let headers = manifest_content_type in
  Dream.respond ~status:`Created ~headers body

let get_manifest ~hash body =
  let open Header in
  let etag = [ ("ETag", "\"" ^ hash ^ "\"") ] in
  let headers = manifest_content_type @ etag in
  Dream.respond ~status:`OK ~headers body

let update_manifest body =
  let open Header in
  let headers = manifest_content_type in
  Dream.respond ~status:`OK ~headers body

let delete_manifest = no_content

let head m =
  let* body = Dream.body m in
  let content_length = Printf.sprintf "%d" (String.length body) in
  let headers = Dream.all_headers m in
  let status = Dream.status m in
  let headers' = List.cons ("Content-Length", content_length) headers in
  Dream.empty ~headers:headers' status
