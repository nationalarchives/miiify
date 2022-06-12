let get_manifest ~db ~key = Db.get ~ctx:db ~key
let add_manifest ~db ~key ~json ~message = Db.add ~ctx:db ~key ~json ~message
let update_manifest ~db ~key ~json ~message = Db.add ~ctx:db ~key ~json ~message
let delete_manifest ~db ~key ~message = Db.delete ~ctx:db ~key ~message
let manifest_exists ~db ~key = Db.exists ~ctx:db ~key
let get_hash ~db ~key = Db.get_hash ~ctx:db ~key
