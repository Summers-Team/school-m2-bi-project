# Setting Up GitHub Pages for dbt Documentation

This guide explains how to enable GitHub Pages for the dbt documentation site.

## Automatic Setup

The GitHub Actions workflow (`.github/workflows/deploy-dbt-docs.yml`) is configured to automatically deploy documentation to GitHub Pages when changes are pushed to the `main` branch.

## Repository Configuration

To enable GitHub Pages deployment, a repository administrator needs to configure the following:

### Step 1: Enable GitHub Pages

1. Go to your repository on GitHub
2. Navigate to **Settings** > **Pages**
3. Under **Build and deployment**:
   - **Source**: Select "GitHub Actions"
   - This allows the workflow to deploy directly without using a specific branch

### Step 2: Run the Workflow

After merging this PR to the `main` branch:

1. The workflow will automatically trigger
2. It will generate the dbt documentation
3. Deploy it to GitHub Pages

### Step 3: Access the Documentation

Once deployed, the documentation will be available at:
- **URL**: `https://summers-team.github.io/school-m2-bi-project/`

## Workflow Details

The workflow performs the following steps:

1. **Build Job**:
   - Checks out the repository
   - Sets up Python 3.12
   - Installs dependencies using `uv`
   - Generates dbt documentation using `dbt docs generate --empty-catalog --no-compile`
   - Prepares documentation files for deployment
   - Uploads the artifact for deployment

2. **Deploy Job**:
   - Deploys the artifact to GitHub Pages
   - Creates the `github-pages` environment

## Manual Workflow Trigger

You can also manually trigger the workflow:

1. Go to **Actions** > **Deploy dbt Docs to GitHub Pages**
2. Click **Run workflow**
3. Select the `main` branch
4. Click **Run workflow**

## Troubleshooting

If the deployment fails:

1. **Check Permissions**: Ensure the repository has GitHub Pages enabled and the workflow has the necessary permissions
2. **Review Workflow Logs**: Go to the Actions tab and review the logs for any errors
3. **Verify dbt Configuration**: Ensure the dbt project structure is correct and models can be parsed

## Local Preview

To preview the documentation locally before deployment, see the instructions in [`dbt/README.md`](../dbt/README.md).
