type t;

let convert_post: (~data:string, ~id:string, ~host:string) => t;

let convert_put: (~data:string) => t;

let id: (t) => string;

let json: (t) => Ezjsonm.t;