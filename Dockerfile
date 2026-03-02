FROM ocaml/opam:alpine-ocaml-5.1 as build

# Install system dependencies
RUN sudo apk add --update libev-dev openssl-dev gmp-dev libffi-dev git

# Copy the miiify project with correct ownership
COPY --chown=opam:opam miiify /home/opam/miiify

WORKDIR /home/opam/miiify

# Update opam repository to get latest package versions
RUN opam update

# Install dependencies and build all executables
RUN opam install . --deps-only
RUN opam exec -- dune build @install --profile=release

# Runtime image
FROM alpine as run

RUN adduser miiify --disabled-password

RUN apk add --update libev gmp openssl musl

WORKDIR /home/miiify

# Copy all executables
COPY --from=build /home/opam/miiify/_build/default/bin/main.exe ./miiify
COPY --from=build /home/opam/miiify/_build/default/bin/clone.exe ./miiify-clone
COPY --from=build /home/opam/miiify/_build/default/bin/pull.exe ./miiify-pull
COPY --from=build /home/opam/miiify/_build/default/bin/push.exe ./miiify-push
COPY --from=build /home/opam/miiify/_build/default/bin/import.exe ./miiify-import
COPY --from=build /home/opam/miiify/_build/default/bin/compile.exe ./miiify-compile
COPY --from=build /home/opam/miiify/_build/default/bin/serve.exe ./miiify-serve

# Create directories and set ownership for miiify user
RUN mkdir -p git_store pack_store annotations && chown -R miiify:miiify git_store pack_store annotations

USER miiify

# No default command - docker-compose.yml or docker run will specify the command

