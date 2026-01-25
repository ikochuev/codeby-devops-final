#!/bin/bash

echo "Setting up Kibana index patterns and dashboards..."

# Wait for Kibana to be ready
echo "Waiting for Kibana to be ready..."
until curl -s http://localhost:5601/api/status | grep -q "available"; do
  sleep 5
done

echo "Kibana is ready. Setting up index patterns..."

# Create index pattern for Fluentd logs
curl -X POST "http://localhost:5601/api/saved_objects/index-pattern/fluentd-*" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "attributes": {
      "title": "fluentd-*",
      "timeFieldName": "@timestamp"
    }
  }'

# Create index pattern for Docker metrics
curl -X POST "http://localhost:5601/api/saved_objects/index-pattern/docker-metrics-*" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "attributes": {
      "title": "docker-metrics-*",
      "timeFieldName": "@timestamp"
    }
  }'

echo "Kibana setup completed!"
