Welcome to your new dbt project!

### Using the starter project

Try running the following commands:
- dbt run
- dbt test

### Viewing dbt Documentation

#### Online Documentation
The dbt documentation is automatically generated and deployed to GitHub Pages on every push to the `main` branch. You can access the live documentation at:
- https://summers-team.github.io/school-m2-bi-project/

#### Local Documentation Preview
To preview the dbt documentation locally:

1. **Generate the documentation:**
   ```bash
   cd dbt
   # First, ensure you have a valid profiles.yml configured
   # Then generate docs (requires database connection for full catalog)
   uv run --project .. dbt docs generate
   
   # Alternatively, generate docs without database connection (empty catalog)
   uv run --project .. dbt parse
   uv run --project .. dbt docs generate --empty-catalog --no-compile
   ```

2. **Serve the documentation:**
   ```bash
   uv run --project .. dbt docs serve
   ```

3. **Open your browser:**
   The documentation will be available at `http://localhost:8080`

The documentation includes:
- Data lineage graphs
- Model descriptions and metadata
- Column-level documentation
- Test results and data quality checks
- Source freshness information

### Resources:
- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](https://community.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices
