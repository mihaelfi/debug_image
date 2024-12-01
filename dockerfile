FROM ubuntu20-04-dotnet-6-debug-base:1.0.0

# Copy startup-script
COPY startup-script.py /scripts/startup-script.py

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Default entrypoint (starts supervisor)
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]