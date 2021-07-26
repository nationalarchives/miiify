open Ezjsonm;

type t = {id: string, json: Ezjsonm.t}

let gen_iri = (host, id) => {
  "http://" ++ host ++ "/annotations/" ++ id;
};

// id autogenerated or via slug
let convert_post = (~data, ~id, ~host) => {
    let json = from_string(data);
    let iri = gen_iri(host, id);
    let json_with_id = update(json, ["id"], Some(string(iri)));
    let json' = `O(get_dict(json_with_id));
    {id, json:json'}
};

// id contained in body
let convert_put = (~data) => {
    let json = from_string(data);
    let id = get_string(find(json, ["id"]));
    {id, json}
}

// accessors
let id = (r) => r.id;

let json = (r) => r.json;