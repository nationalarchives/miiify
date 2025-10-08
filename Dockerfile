FROM ocaml/opam:alpine-ocaml-5.1 as build

# Install system dependencies
RUN sudo apk add --update libev-dev openssl-dev gmp-dev libffi-dev git
ADD miiify .

# Update opam repository to get latest package versions
RUN opam update

RUN opam install . --deps-only
# Build project
RUN opam exec -- dune build bin/main.exe --profile=release

# runtime image
FROM alpine as run

RUN adduser miiify --disabled-password

RUN apk add --update libev gmp openssl musl

WORKDIR /home/miiify

COPY --from=build /home/opam/_build/default/bin/main.exe ./app
COPY --from=build /home/opam/config.json ./config.json
COPY assets assets

# Create db directory and set ownership for miiify user
RUN mkdir -p db && chown -R miiify:miiify db

USER miiify

RUN openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 3650 -nodes -subj "/C=UK/ST=foo/L=bar/O=baz/OU= Department/CN=localhost.local"

ENTRYPOINT ["/home/miiify/app"]

