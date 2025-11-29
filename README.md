# Projet M2 BI

This is a project for M2 BI, featuring infrastructure as code using Terraform/OpenTofu for GCP resources and dbt for data transformation.

## Infrastructure deployment

Detailed prerequisites and step-by-step deployment instructions now live in [`infrastructure/README.md`](infrastructure/README.md).

## Usage

- **dbt:** Use the generated `dbt/profiles.yml` for development and production environments.
- **BigQuery:** Access the dev and prod datasets as specified in the Terraform outputs.

### Local environment with uv and mise

- Install [uv](https://docs.astral.sh/uv/getting-started/installation/) to manage the Python environment described by `pyproject.toml` and `uv.lock`.
- Install [mise](https://mise.jdx.dev/) to manage tools and tasks.

Most tasks are automated via `mise`. Run `mise tasks` to see available commands.

Common workflows:

```bash
# 1. Sync environment variables
mise run sync_env

# 2. Generate configuration files (dbt profiles, prefect config)
mise run dbt:render_profiles
mise run prefect:render_configs

# 3. Run dbt commands
uv run -- dbt debug
```

- If you prefer to activate the virtual environment manually, first synchronize dependencies and then source `.venv`:

	```bash
	uv sync
	source .venv/bin/activate
	dbt debug
	```

	See the [uv running commands guide](https://docs.astral.sh/uv/guides/projects/#running-commands) for more patterns.

	Lock requirements with [`uv pip compile pyproject.toml -o requirements.txt`](https://docs.astral.sh/uv/pip/compile/#locking-requirements).

## Notes

- Service account keys are not committed to version control (ignored in `.gitignore`).
- For production deployments, consider using CI/CD pipelines with secure credential management.