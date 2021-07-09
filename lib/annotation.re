
[@deriving yojson]
type annotation_object = {
  [@key "@context"] context: string,
  id: string,
  [@key "type"] type_: string,
  body: string,
  target: string,
};

type t = annotation_object;

let create = (s) => {
  let json = Yojson.Safe.from_string(s);
  annotation_object_of_yojson(json);
}

let id = (obj) => obj.id;