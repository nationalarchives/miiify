(lang dune 2.8)

(name miiify)

(generate_opam_files true)

(package
 (name miiify)
 (synopsis "W3C annotation server")
 (description "A simple W3C annotation server that stores data to git")
 (depends
  (dream (>= 1.0.0~alpha2))
  (ezjsonm (>= 1.2.0))
  (irmin-unix (>= 2.7.2))
  (atdgen (>= 2.2.1))
  (ptime (>= 0.8.5))
  (uuidm (>= 0.9.7))
  (reason (>= 3.7.0))))
