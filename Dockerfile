# Stage 1: Build stage using the official uv image
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder

# Enable bytecode compilation and optimized linking for speed
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy

WORKDIR /app

# Install dependencies first (better Docker caching)
# Note: --no-install-project ensures we only build the environment first
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project --no-dev

# Add the rest of your microservice code
ADD . /app

# Final sync to include the project itself
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

# Stage 2: Final runtime stage (slim and secure)
FROM python:3.12-slim-bookworm
WORKDIR /app

# Copy only the virtual environment and app code from the builder
COPY --from=builder /app /app

# Place the virtual environment's binaries at the front of the PATH
ENV PATH="/app/.venv/bin:$PATH"

# Run as non-root for security (Principle of Least Privilege)
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8080
CMD ["python", "main.py"]