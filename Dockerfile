FROM ocaml/opam:alpine as build

# Install system dependencies
RUN sudo apk add --update libev-dev openssl-dev gmp-dev libffi-dev

WORKDIR /home/opam

# Install dependencies
ADD miiify.opam miiify.opam
RUN opam install . --deps-only

# Build project
ADD . .
RUN opam exec -- dune build ./bin/main.exe

FROM alpine as run

RUN adduser miiify --disabled-password

RUN apk add --update libev gmp libressl zlib openssl

WORKDIR /home/miiify

COPY --from=build /home/opam/_build/default/bin/main.exe ./app

USER miiify

EXPOSE 8080

ENTRYPOINT ["/home/miiify/app"]

