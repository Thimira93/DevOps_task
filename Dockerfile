# Use the latest Ubuntu base image
FROM ubuntu:latest

# Install system dependencies
RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv nginx

# Create and activate a virtual environment
RUN python3 -m venv /opt/venv

# Install Python packages in the virtual environment
RUN /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install flask gunicorn

# Remove default Nginx configuration
RUN rm /etc/nginx/sites-enabled/default

# Copy Nginx configuration
COPY nginx.conf /etc/nginx/sites-enabled/

# Copy the Flask application
COPY app /app

# Set the working directory
WORKDIR /app

# Set environment variables for the virtual environment
ENV PATH="/opt/venv/bin:$PATH"

# Start Gunicorn and Nginx
CMD service nginx start && gunicorn --bind 127.0.0.1:8000 app:app
