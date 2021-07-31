
let create_basic_container = (data) => {
  Schema_j.basic_container_of_string(data);
}

let basic_container = (~data) => {
  switch(create_basic_container(data)) {
    | exception (_) => Result.error("does not conform to basic container");
    | _ => Result.ok();
  }
}