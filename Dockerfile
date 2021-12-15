FROM ocaml/opam:alpine as build

# Install system dependencies
RUN sudo apk add --update libev-dev openssl-dev gmp-dev libffi-dev

WORKDIR /home/opam

# Install dependencies
ADD miiify.opam miiify.opam
RUN opam pin add -n reason https://github.com/reasonml/reason.git
RUN opam install . --deps-only

# Build project
ADD . .
RUN opam exec -- dune build

FROM alpine as run

RUN adduser miiify --disabled-password

RUN apk add --update libev gmp openssl

WORKDIR /home/miiify

COPY --from=build /home/opam/_build/default/bin/main.exe ./app

COPY assets assets

USER miiify

RUN openssl req -x509 -out server.crt -keyout server.key \
  -newkey rsa:2048 -nodes -sha256 \
  -subj '/CN=localhost' -extensions EXT -config <( \
   printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")

ENTRYPOINT ["/home/miiify/app"]

