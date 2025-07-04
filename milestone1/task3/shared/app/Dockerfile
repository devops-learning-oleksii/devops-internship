# Stage 1: Build dependencies
FROM python:3.9-alpine as builder

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache --virtual .build-deps \
    build-base \
    gcc \
    musl-dev \
    pkgconfig

# Copy and install requirements
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Runtime image
FROM python:3.9-alpine

WORKDIR /app

# Copy only the installed packages from the builder stage
COPY --from=builder /install /usr/local

# Copy application files
COPY app.py .
COPY templates/ templates/

# Create logs directory
RUN mkdir -p /app/logs

# Clean up and minimize image size
RUN find /usr/local \( -type d -a -name test -o -name tests -o -name '__pycache__' \) -o \
    \( -type f -a -name '*.pyc' -o -name '*.pyo' \) -exec rm -rf '{}' \; 2>/dev/null || true

# Set MongoDB_HOST environment variable
ENV MONGO_HOST=mongodb

# Expose port for the app
EXPOSE 5000

# Command to run the app
CMD ["python", "app.py"]