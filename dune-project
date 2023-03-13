(lang dune 2.8)

(name miiify)

(generate_opam_files true)

(source
 (github nationalarchives/miiify))

(license MIT)

(authors "John Moore")

(maintainers "john.moore@nationalarchives.gov.uk")

(package
 (name miiify)
 (synopsis "W3C annotation server")
 (description "A simple W3C annotation server that stores data to git")
 (depends
  (dream
   (>= 1.0.0~alpha4))
  (ezjsonm
   (>= 1.2.0))
  (irmin-git
   (>= 3.6.0))
  (atdgen
   (>= 2.2.1))
  (ptime
   (>= 0.8.5))
  (uuidm
   (>= 0.9.7))))
