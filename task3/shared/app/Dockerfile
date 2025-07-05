FROM python:3.9-alpine as builder

WORKDIR /build

RUN apk add --no-cache --virtual .build-deps \
    build-base \
    gcc \
    musl-dev \
    pkgconfig

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.9-alpine

WORKDIR /app

COPY --from=builder /install /usr/local

COPY app.py .
COPY templates/ templates/

RUN mkdir -p /app/logs

RUN find /usr/local \( -type d -a -name test -o -name tests -o -name '__pycache__' \) -o \
    \( -type f -a -name '*.pyc' -o -name '*.pyo' \) -exec rm -rf '{}' \; 2>/dev/null || true

ENV MONGO_HOST=mongodb

EXPOSE 5000

CMD ["python", "app.py"]