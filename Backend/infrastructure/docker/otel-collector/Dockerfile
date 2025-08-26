# OpenTelemetry Collector for Spatial Platform
# Enterprise-grade telemetry collection with distroless security

FROM otel/opentelemetry-collector-contrib:latest

# Copy collector configuration files
# Volume mounts will handle data directories
COPY infrastructure/docker/otel-collector/otel-collector-config.yaml /etc/otel-collector-config.yaml
COPY infrastructure/docker/otel-collector/otel-collector-development.yaml /etc/otel-collector-dev.yaml

# Expose OTEL standard ports
EXPOSE 4317 4318 8888 8889 13133 14250

# Use default distroless entrypoint and configuration
ENTRYPOINT ["/otelcol-contrib"]
CMD ["--config=/etc/otel-collector-config.yaml"]