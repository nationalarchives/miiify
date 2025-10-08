#!/bin/bash

# Run unit tests with dune
run_unit_tests() {
  echo "Running unit tests with dune..."
  cd .. && dune runtest
  if [ $? -ne 0 ]; then
    echo "Unit tests failed. Stopping."
    exit 1
  fi
  cd test
  echo "Unit tests passed."
}

case $1 in
  "git")
    run_unit_tests
    echo "Testing with Git backend..."
    MIIIFY_BACKEND=git docker compose up --force-recreate -d
    
    # Check if service is responding
    echo "Waiting for service to be ready..."
    for i in {1..10}; do
      if curl -s http://localhost:10000/ > /dev/null 2>&1; then
        echo "Service is ready"
        break
      fi
      echo "Attempt $i/10: Service not ready yet..."
      sleep 2
    done
    
    # Show container logs if not responding
    if ! curl -s http://localhost:10000/ > /dev/null 2>&1; then
      echo "Service failed to start. Logs:"
      docker compose logs
      docker compose down
      exit 1
    fi
    
    # Run tests
    rspec integration.rb -fd
    docker compose down;;
  "pack")
    run_unit_tests
    echo "Testing with Pack backend..."
    MIIIFY_BACKEND=pack docker compose up --force-recreate -d
    
    # Check if service is responding
    echo "Waiting for service to be ready..."
    for i in {1..10}; do
      if curl -s http://localhost:10000/ > /dev/null 2>&1; then
        echo "Service is ready"
        break
      fi
      echo "Attempt $i/10: Service not ready yet..."
      sleep 2
    done
    
    # Show container logs if not responding
    if ! curl -s http://localhost:10000/ > /dev/null 2>&1; then
      echo "Service failed to start. Logs:"
      docker compose logs
      docker compose down
      exit 1
    fi
    
    # Run tests
    rspec integration.rb -fd
    docker compose down;;
  "both")
    run_unit_tests
    echo "Testing Pack backend..."
    MIIIFY_BACKEND=pack docker compose up --force-recreate -d
    sleep 3
    rspec integration.rb -fd
    docker compose down
    
    echo "Testing Git backend..."
    MIIIFY_BACKEND=git docker compose up --force-recreate -d
    sleep 3
    rspec integration.rb -fd
    docker compose down;;
  *) echo "supported backends: git | pack | both";;
esac