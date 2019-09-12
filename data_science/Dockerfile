FROM python:3.7.4-buster

ENV APP_DIR=/app

WORKDIR ${APP_DIR}

COPY requirements.txt .
RUN pip3 install --upgrade pip -r requirements.txt

COPY . ${APP_DIR}
