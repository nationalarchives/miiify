FROM ocaml/opam:alpine as build

# Install system dependencies
RUN sudo apk add --update libev-dev openssl-dev gmp-dev libffi-dev

WORKDIR /home/opam

# Install dependencies
ADD miiify.opam miiify.opam
RUN opam install . --deps-only --unlock-base

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

RUN openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 3650 -nodes -subj "/C=UK/ST=foo/L=bar/O=baz/OU= Department/CN=localhost.local"

ENTRYPOINT ["/home/miiify/app"]

