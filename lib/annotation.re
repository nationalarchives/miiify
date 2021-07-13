open Annotate_t;

type t = basic_annotation;

let create = (s) => {
  Annotate_j.basic_annotation_of_string(s);
}

let id = (obj) => obj.id;