
# Kademos Yggdrasil Makefile — local developer UX and CI parity

SHELL := /bin/bash

.PHONY: help dev up down logs test test-gk test-fo lint sbom dast clean

help:
    @echo "Targets:"
    @echo "  dev        - Start core services in dev mode"
    @echo "  up         - docker compose up (default stack)"
    @echo "  down       - docker compose down"
    @echo "  logs       - Tail logs from all services"
    @echo "  test       - Run all tests (Node + Python)"
    @echo "  test-gk    - Run Gatekeeper tests (Jest)"
    @echo "  test-fo    - Run Flag-Oracle tests (pytest)"
    @echo "  lint       - Run pre-commit on all files"
    @echo "  sbom       - Generate CycloneDX SBOM (placeholder)"
    @echo "  dast       - Run ZAP Baseline against local Gatekeeper"
    @echo "  clean      - Remove temp and cache files"

dev:
    @echo "Starting core services in dev mode (placeholder)"
    # e.g., npm run dev / uvicorn --reload — to be wired in M1
    @echo "Implement dev runners in M1"

up:
    docker compose up -d

down:
    docker compose down -v

logs:
    docker compose logs -f --tail=200

test:
    $(MAKE) test-gk || true
    $(MAKE) test-fo || true

test-gk:
    @if [ -d core/gatekeeper ]; then cd core/gatekeeper && npm install && npm test; else echo "gatekeeper not present yet"; fi

test-fo:
    @if [ -d core/flag-oracle ]; then \
    cd core/flag-oracle && python -m venv .venv && source .venv/bin/activate && \
    pip install -r requirements.txt -r requirements-dev.txt && pytest -q; \
    else echo "flag-oracle not present yet"; fi

lint:
    pre-commit run --all-files || true

sbom:
    @echo "Generating SBOM (placeholder) — wire CycloneDX in CI"

dast:
    @echo "Running ZAP Baseline against http://localhost:8080 (placeholder)"
    @echo "Use .zap/rules.tsv and dockerized ZAP in CI (M4)"

clean:
    rm -rf **/__pycache__ **/.pytest_cache core/flag-oracle/.venv || true
