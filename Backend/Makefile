.PHONY: install install-dev run lint format typecheck test freeze

# ─── Setup ───────────────────────────────────────────────────
install:
	pip install -e .

install-dev:
	pip install -e ".[dev]"

# Instala Y sella versiones en requirements.lock
bootstrap:
	pip install -e ".[dev]"
	pip freeze > requirements.lock

# ─── Servidor ────────────────────────────────────────────────
run:
	uvicorn app.main:app --reload

# ─── Calidad de código ───────────────────────────────────────
lint:
	ruff check .

format:
	ruff format .

typecheck:
	mypy app/

# ─── Tests ───────────────────────────────────────────────────
test:
	pytest -v

# ─── Todo en uno ─────────────────────────────────────────────
check: lint typecheck test