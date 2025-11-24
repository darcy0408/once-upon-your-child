#!/bin/bash
for i in {1..10}; do
  curl -s https://story-weaver-app-production.up.railway.app/health &
done
wait
echo "All requests completed"
