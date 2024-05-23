# Use the latest Ubuntu base image
FROM ubuntu:latest

# Install dependencies
RUN apt-get update && \
    apt-get install -y python3 python3-pip nginx && \
    pip3 install flask gunicorn

# Remove default Nginx configuration
RUN rm /etc/nginx/sites-enabled/default

# Copy Nginx configuration
COPY nginx.conf /etc/nginx/sites-enabled/

# Copy the Flask application
COPY app /app

# Set the working directory
WORKDIR /app

# Start Gunicorn and Nginx
CMD service nginx start && gunicorn --bind 0.0.0.0:8000 app:app
