type t;

let from_post: (~data:string, ~id:list(string), ~host:string) => result(t,string);

let from_put: (~data:string, ~id:list(string), ~host:string) => result(t, string);

let id: (t) => list(string);

let json: (t) => Ezjsonm.t;

let to_string: (t) => string;