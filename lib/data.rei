type t;

let from_post: (~data:string, ~id:string, ~host:string) => t;

let from_put: (~data:string) => t;

let id: (t) => string;

let json: (t) => Ezjsonm.t;