open Ezjsonm;

type t = {id: string, json: Ezjsonm.t}

let convert = (data: string) => {
    let json = from_string(data);
    let id = get_string(find(json, ["id"]));
    {id, json}
}

let id = (r) => r.id;

let json = (r) => r.json;