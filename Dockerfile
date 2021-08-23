FROM ocaml/opam:alpine as build

# Install system dependencies
RUN sudo apk add --update libev-dev openssl-dev gmp-dev libffi-dev

WORKDIR /home/opam

# Install dependencies
ADD miiify.opam miiify.opam
RUN opam install . --deps-only

# Build project
ADD . .
RUN opam exec -- dune build

FROM alpine as run

RUN adduser miiify --disabled-password

RUN apk add --update libev gmp

WORKDIR /home/miiify

COPY --from=build /home/opam/_build/default/bin/main.exe ./app

USER miiify

ENTRYPOINT ["/home/miiify/app"]

