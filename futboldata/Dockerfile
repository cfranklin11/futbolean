FROM r-base:3.6.0

RUN apt-get update && apt-get -y install \
  libcurl4-openssl-dev \
  libxml2 \
  libxml2-dev \
  libssl-dev

ENV APP_DIR=/app

WORKDIR ${APP_DIR}

COPY init.R ./
RUN Rscript init.R

COPY . .

EXPOSE 8080

CMD Rscript app.R
