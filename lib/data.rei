type t;

let post_annotation: (~data:string, ~id:list(string), ~host:string) => result(t,string);
let post_container: (~data:string, ~id:list(string), ~host:string) => result(t,string);

let put_annotation: (~data:string, ~id:list(string), ~host:string) => result(t, string);


let id: (t) => list(string);

let json: (t) => Ezjsonm.value;

let to_string: (t) => string;