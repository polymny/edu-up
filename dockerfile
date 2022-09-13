FROM rust:slim

WORKDIR /usr/src/server/

RUN DEBIAN_FRONTEND=noninteractive apt update
RUN DEBIAN_FRONTEND=noninteractive apt install -y openssl libssl-dev pkg-config imagemagick ffmpeg git qpdf bc jq

RUN sed -i -E 's/(^.*pattern="PDF".*$)/<!-- \1 -->/' /etc/ImageMagick-6/policy.xml

RUN cargo init .
RUN rm -rf .git

COPY server/Cargo.toml server/Cargo.docker.toml server/Cargo.lock /usr/src/server/
RUN mv Cargo.toml Cargo.toml.tmp
RUN mv Cargo.docker.toml Cargo.toml
RUN cargo build

RUN mv Cargo.toml.tmp Cargo.toml

COPY . /usr/src/

CMD [ "sh", "-c", "cargo run --bin reset-db && cargo run" ]