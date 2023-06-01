FROM python:3.9

RUN apt-get update
RUN curl -sL https://deb.nodesource.com/setup_14.x |  bash -
RUN apt-get install -y nodejs shellcheck

WORKDIR /opt
RUN git clone https://github.com/mtlynch/tinypilot
ARG INSTALL_DIR=/opt/tinypilot
WORKDIR ${INSTALL_DIR}

RUN pip install --requirement requirements.txt && pip install --requirement dev_requirements.txt
RUN npm install

RUN ./dev-scripts/build

ENV APP_SETTINGS_FILE=${INSTALL_DIR}/dev_app_settings.cfg
ENV HOST=0.0.0.0
ENV PORT=8000
EXPOSE $PORT

CMD ["python", "app/main.py"]
