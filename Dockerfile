FROM ocaml/opam:alpine-ocaml-5.1 as build

# Install system dependencies
RUN sudo apk add --update libev-dev openssl-dev gmp-dev libffi-dev git

# Copy the miiify project with correct ownership
COPY --chown=opam:opam miiify /home/opam/miiify

WORKDIR /home/opam/miiify

# Update opam repository to get latest package versions
RUN opam update

# Install dependencies and build
RUN opam install . --deps-only
RUN opam exec -- dune build bin/serve.exe --profile=release

# Runtime image
FROM alpine as run

RUN adduser miiify --disabled-password

RUN apk add --update libev gmp openssl musl

WORKDIR /home/miiify

# Copy the serve executable
COPY --from=build /home/opam/miiify/_build/default/bin/serve.exe ./miiify-serve

# Create db directory and set ownership for miiify user
RUN mkdir -p db && chown -R miiify:miiify db

USER miiify

ENTRYPOINT ["/home/miiify/miiify-serve"]

