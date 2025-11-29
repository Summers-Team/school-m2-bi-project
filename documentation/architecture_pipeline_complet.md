# Architecture Complète du Pipeline Data BigMedia

## Vue d'Ensemble de l'Architecture ELT

Ce document décrit l'architecture complète du pipeline de données pour le projet BigMedia, de la génération des données brutes jusqu'aux dashboards Power BI.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PIPELINE DATA BIGMEDIA (ELT)                          │
└─────────────────────────────────────────────────────────────────────────┘

    BRONZE (Raw)          SILVER (Staging)         GOLD (Data Warehouse)
    ════════════          ════════════════         ═════════════════════

┌──────────────┐      ┌──────────────┐        ┌──────────────────┐
│seed_script.py│──────│  GCS Bucket  │────────│  dbt Transform   │
│ (génération) │      │  (raw_data/) │        │  (stg_*, int_*)  │
└──────────────┘      └──────────────┘        └──────────────────┘
        │                     │                        │
        ↓                     ↓                        ↓
   [raw_data/]         [GCS Storage]          [BigQuery Staging]
   - contents.csv      bronze layer            - stg_contents
   - users.csv                                 - stg_users
   - viewing_logs.json                         - stg_viewing_logs
   - social_media.json                         - stg_social_media
                                                       │
                                                       ↓
                                              ┌─────────────────┐
                                              │  Star Schema    │
                                              │  (dim_*, fct_*) │
                                              └─────────────────┘
                                                       │
                                                       ↓
                                              [BigQuery Warehouse]
                                              - DIM_Users
                                              - DIM_Content
                                              - DIM_Devices
                                              - DIM_Date
                                              - FCT_Viewings
                                                       │
                                                       ↓
                                              ┌─────────────────┐
                                              │   Power BI      │
                                              │  (Dashboards)   │
                                              └─────────────────┘

ORCHESTRATION : Prefect Cloud + Prefect Flows
INFRASTRUCTURE : Terraform (GCP)
TRANSFORMATION : dbt (BigQuery)
```

---

## 1. Couche Bronze : Génération et Ingestion des Données Brutes

### 1.1 Script de Génération (`seed_script.py`)

**Emplacement** : `prefect_flows/seed_scripts/seed_script.py`

**Rôle** : Générer des données fictives réalistes pour simuler les sources de données de BigMedia.

**Données Générées** :

| Fichier | Format | Description | Volumétrie |
|---------|--------|-------------|------------|
| `contents.csv` | CSV | Catalogue de contenus (séries, épisodes) | 50 entrées |
| `users.csv` | CSV | Utilisateurs du service VoD | 500 entrées |
| `viewing_logs.json` | JSON Lines | Logs de visionnage détaillés | 10 000 entrées |
| `social_media_mentions.json` | JSON Lines | Mentions réseaux sociaux | 2 000 entrées |

**Concepts Clés** :

1. **Intégrité Référentielle** : Les `viewing_logs` référencent des `user_id` et `content_id` existants
2. **Réalisme Temporel** : Les timestamps couvrent les 30 derniers jours
3. **Variété des Données** : Mix de CSV (structuré) et JSON (semi-structuré) pour coller au contexte Big Data

**Pourquoi Faker ?**
- Génération de données cohérentes et réalistes (noms, dates, textes)
- Support du français (Faker('fr_FR'))
- Reproductibilité partielle pour les tests

---

### 1.2 Flow Prefect d'Ingestion (`refill_bucket.py`)

**Emplacement** : `prefect_flows/refill_bucket.py`

**Rôle** : Orchestrer la génération des données et leur upload vers GCS.

**Architecture du Flow** :

```python
@flow refill_bucket_flow()
    │
    ├─> @task generate_seed_data()
    │   │   - Exécute seed_script.py via subprocess
    │   │   - Valide la création de tous les fichiers attendus
    │   └─> Retourne: Path vers raw_data/
    │
    └─> @task upload_files_to_gcs(data_dir)
        │   - Authentification via bloc 'gcp-credentials'
        │   - Upload vers gs://test-terraform-473818-ingested-data/raw_data/
        └─> Retourne: Métadonnées (fichiers, tailles, URIs)
```

**Stratégies Implémentées** :

#### a) Isolation via Subprocess

```python
subprocess.run([sys.executable, str(SEED_SCRIPT_PATH)], ...)
```

**Pourquoi ?**
- Le script de seed reste indépendant et réutilisable
- Isolation des logs (stdout/stderr capturés séparément)
- Facilite le debugging (on peut exécuter le seed sans Prefect)

#### b) Retry Pattern

```python
@task(retries=3, retry_delay_seconds=30)
```

**Pourquoi ?**
- Les uploads réseau peuvent échouer temporairement
- GCP peut throttler les requêtes en cas de pic
- Robustesse : maximise la fiabilité sans intervention manuelle

#### c) Authentification Hybride (Cloud + Local)

```python
try:
    gcp_credentials_block = GcpCredentials.load("gcp-credentials")
    storage_client = storage.Client(credentials=...)
except:
    storage_client = storage.Client()  # ADC fallback
```

**Pourquoi ?**
- **Mode Cloud** : Utilise le bloc Prefect centralisé (production)
- **Mode Local** : Fallback sur `gcloud auth` pour le développement
- Flexibilité maximale selon l'environnement d'exécution

**Organisation dans GCS** :

```
gs://test-terraform-473818-ingested-data/
└── raw_data/
    ├── contents.csv
    ├── users.csv
    ├── viewing_logs.json
    └── social_media_mentions.json
```

Le préfixe `raw_data/` permet :
- Une organisation logique dans le bucket (séparation Bronze/Silver/Gold si besoin)
- Une gestion des permissions par préfixe
- Une traçabilité claire de la provenance des données

---

## 2. Couche Silver/Gold : Transformation dbt

### 2.1 Architecture des Modèles dbt (à construire)

**Emplacement** : `dbt/models/`

**Structure Recommandée** :

```
dbt/models/
├── staging/                    # Couche Silver : Nettoyage
│   ├── _staging.yml           # Documentation et tests des sources
│   ├── stg_contents.sql       # Nettoyage et typage du catalogue
│   ├── stg_users.sql          # Standardisation des utilisateurs
│   ├── stg_viewing_logs.sql   # Parsing JSON + calculs de base
│   └── stg_social_media.sql   # Extraction + sentiment (random)
│
├── intermediate/               # Couche Silver : Business Logic
│   ├── int_viewing_enriched.sql    # Jointures viewing + content + user
│   └── int_social_sentiment.sql    # Agrégation sentiment par contenu
│
└── marts/                      # Couche Gold : Star Schema
    ├── dimensions/
    │   ├── dim_users.sql      # Dimension Utilisateurs
    │   ├── dim_content.sql    # Dimension Contenus
    │   ├── dim_devices.sql    # Dimension Appareils
    │   └── dim_date.sql       # Dimension Temporelle
    │
    └── facts/
        └── fct_viewings.sql   # Table de faits centrale
```

### 2.2 Logique de Transformation par Couche

#### Staging (Bronze → Silver)

**Objectif** : Nettoyer, typer, standardiser les données brutes.

**Exemple : `stg_viewing_logs.sql`**

```sql
-- Nettoyage des logs de visionnage
WITH source AS (
    SELECT * FROM {{ source('gcs', 'viewing_logs') }}
),

cleaned AS (
    SELECT
        session_id,
        user_id,
        content_id,
        TIMESTAMP(start_timestamp) AS start_timestamp,
        TIMESTAMP(end_timestamp) AS end_timestamp,
        watch_duration_seconds,
        LOWER(TRIM(device_type)) AS device_type,
        LOWER(TRIM(os)) AS os
    FROM source
    WHERE 
        session_id IS NOT NULL
        AND watch_duration_seconds > 0  -- Exclure les sessions invalides
)

SELECT * FROM cleaned
```

**Concepts Clés** :
- **Source Macro** : `{{ source() }}` référence les données GCS via `sources.yml`
- **Nettoyage** : Suppression des espaces, normalisation de la casse
- **Validation** : Filtrage des données incohérentes
- **Typage** : Cast explicite des timestamps

#### Intermediate (Silver → Silver enrichi)

**Objectif** : Appliquer la logique métier, créer des jointures réutilisables.

**Exemple : `int_viewing_enriched.sql`**

```sql
-- Enrichissement des logs avec les métadonnées de contenu
WITH viewings AS (
    SELECT * FROM {{ ref('stg_viewing_logs') }}
),

contents AS (
    SELECT * FROM {{ ref('stg_contents') }}
),

users AS (
    SELECT * FROM {{ ref('stg_users') }}
),

enriched AS (
    SELECT
        v.session_id,
        v.user_id,
        v.content_id,
        v.start_timestamp,
        v.watch_duration_seconds,
        c.duration_minutes AS content_duration_minutes,
        c.genre,
        c.production_type,
        u.country,
        u.age_group,
        v.device_type,
        v.os,
        -- Calcul du taux de complétion
        SAFE_DIVIDE(v.watch_duration_seconds, c.duration_minutes * 60) AS completion_rate,
        -- Indicateur de visionnage complet (>90%)
        CASE 
            WHEN SAFE_DIVIDE(v.watch_duration_seconds, c.duration_minutes * 60) >= 0.9 
            THEN TRUE 
            ELSE FALSE 
        END AS is_completed_view
    FROM viewings v
    LEFT JOIN contents c ON v.content_id = c.content_id
    LEFT JOIN users u ON v.user_id = u.user_id
)

SELECT * FROM enriched
```

**Concepts Clés** :
- **Ref Macro** : `{{ ref() }}` crée des dépendances entre modèles (DAG)
- **Jointures** : Combiner les sources pour enrichir les données
- **Calculs Métier** : completion_rate, is_completed_view (KPIs métier)
- **SAFE_DIVIDE** : Éviter les divisions par zéro (robustesse)

#### Marts (Silver → Gold : Star Schema)

**Objectif** : Créer le modèle dimensionnel optimisé pour Power BI.

**Exemple : `dim_content.sql`**

```sql
-- Dimension Contenus : SCD Type 1 (dernière valeur)
WITH source AS (
    SELECT * FROM {{ ref('stg_contents') }}
),

dimension AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['content_id']) }} AS content_sk,
        content_id,
        title,
        series_name,
        genre,
        target_age_group,
        production_type,  -- Colonne clé pour l'analyse Original vs Achat
        EXTRACT(YEAR FROM release_date) AS release_year,
        duration_minutes,
        release_date
    FROM source
)

SELECT * FROM dimension
```

**Exemple : `fct_viewings.sql`**

```sql
-- Table de faits : Visionnages avec clés étrangères vers dimensions
WITH enriched_viewings AS (
    SELECT * FROM {{ ref('int_viewing_enriched') }}
),

facts AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['session_id']) }} AS viewing_sk,
        {{ dbt_utils.generate_surrogate_key(['user_id']) }} AS user_fk,
        {{ dbt_utils.generate_surrogate_key(['content_id']) }} AS content_fk,
        PARSE_DATE('%Y%m%d', FORMAT_TIMESTAMP('%Y%m%d', start_timestamp)) AS date_fk,
        {{ dbt_utils.generate_surrogate_key(['device_type', 'os']) }} AS device_fk,
        
        -- Métriques
        ROUND(watch_duration_seconds / 60.0, 2) AS view_duration_minutes,
        ROUND(completion_rate, 3) AS completion_rate,
        is_completed_view,
        
        -- Timestamps (pour drill-down temporel)
        start_timestamp,
        
        -- Dimensions dégénérées (pour filtrage rapide)
        session_id
    FROM enriched_viewings
)

SELECT * FROM facts
```

**Concepts Clés du Star Schema** :

1. **Surrogate Keys** : Clés techniques générées (indépendantes des clés métier)
   - Avantages : Stabilité, performance, gestion des SCD
   - Macro dbt_utils : Hash consistant des clés naturelles

2. **Grain de la Table de Faits** : Une ligne = une session de visionnage
   - Permet l'analyse au niveau le plus fin
   - Agrégations possibles : par user, par content, par date, etc.

3. **Dénormalisation Partielle** : Dimensions dégénérées dans la fact table
   - session_id : Pour tracer un visionnage spécifique
   - start_timestamp : Pour analyses temporelles détaillées

4. **Dimensions Conformes** : DIM_Date réutilisable pour d'autres facts
   - Pattern classique du Data Warehouse
   - Facilite les analyses cross-domain

---

### 2.3 Flow Prefect dbt (`pipeline.py`)

**Emplacement** : `prefect_flows/pipeline.py`

**Rôle** : Orchestrer l'exécution de dbt (run + test).

**Architecture du Flow** :

```python
@flow dbt_full_pipeline(target="dev")
    │
    ├─> @task run_dbt_models(target)
    │   │   Mode Cloud : Charge bloc 'dbt-cli-profile-{target}'
    │   │   Mode Local : Utilise dbt/profiles.yml
    │   └─> Exécute: dbt run --target {target}
    │
    └─> @task test_dbt_models(target)
        │   Exécute: dbt test --target {target}
        └─> Valide l'intégrité des données transformées
```

**Stratégies Implémentées** :

#### a) Multi-Environnement (Dev/Prod)

```python
dbt_full_pipeline(target="dev")   # Dataset : test_terraform_473818_dev
dbt_full_pipeline(target="prod")  # Dataset : test_terraform_473818_prod
```

**Pourquoi ?**
- **Dev** : Expérimentation rapide, 1 thread, données éphémères (90 jours)
- **Prod** : Données officielles, 4 threads, pas d'expiration

#### b) Authentification Hybride (comme refill_bucket.py)

**Mode Cloud** :
```python
bigquery_target_configs = BigQueryTargetConfigs.load(f"bigquery-target-configs-{target}")
dbt_cli_profile = DbtCliProfile.load(f"dbt-cli-profile-{target}")
```

**Mode Local** :
```python
DbtCoreOperation(
    commands=[f"dbt run --target {target}"],
    profiles_dir=str(dbt_project_dir)
)
```

**Blocs Prefect Utilisés** :

| Bloc | Type | Usage |
|------|------|-------|
| `bigquery-target-configs-dev` | BigQueryTargetConfigs | Credentials + dataset dev |
| `bigquery-target-configs-prod` | BigQueryTargetConfigs | Credentials + dataset prod |
| `dbt-cli-profile-dev` | DbtCliProfile | Profil dbt complet (dev) |
| `dbt-cli-profile-prod` | DbtCliProfile | Profil dbt complet (prod) |
| `dbt-operation-run-dev` | DbtCoreOperation | Opération pré-configurée (run dev) |
| `dbt-operation-test-prod` | DbtCoreOperation | Opération pré-configurée (test prod) |

---

## 3. Pipeline Complet End-to-End

### 3.1 Séquence d'Exécution

```bash
# Étape 1 : Générer et uploader les données brutes (couche Bronze)
uv run python prefect_flows/refill_bucket.py

# Résultat : Fichiers dans gs://test-terraform-473818-ingested-data/raw_data/

# Étape 2 : Transformer les données avec dbt (couches Silver + Gold)
uv run python prefect_flows/pipeline.py

# Résultat : Tables dans BigQuery test_terraform_473818_dev
#   - Staging : stg_*
#   - Intermediate : int_*
#   - Marts : dim_*, fct_*

# Étape 3 : Connecter Power BI à BigQuery
# Utiliser les tables de marts/ (star schema) comme source de données
```

### 3.2 Pipeline Orchestré par Prefect Cloud (Production)

**Déploiement du Flow d'Ingestion** :

```bash
# Construction du déploiement
prefect deployment build \
    prefect_flows/refill_bucket.py:refill_bucket_flow \
    -n "refill-bucket-weekly" \
    -p default-pool \
    --cron "0 0 * * 0"  # Tous les dimanches à minuit

# Application du déploiement
prefect deployment apply refill_bucket_flow-deployment.yaml
```

**Déploiement du Flow dbt** :

```bash
# Construction du déploiement dev (quotidien)
prefect deployment build \
    prefect_flows/pipeline.py:dbt_full_pipeline \
    -n "dbt-dev-daily" \
    -p default-pool \
    --cron "0 2 * * *" \
    --param target=dev

# Construction du déploiement prod (hebdomadaire)
prefect deployment build \
    prefect_flows/pipeline.py:dbt_full_pipeline \
    -n "dbt-prod-weekly" \
    -p default-pool \
    --cron "0 4 * * 1" \
    --param target=prod

# Application des déploiements
prefect deployment apply dbt_full_pipeline-deployment.yaml
```

**Stratégie de Scheduling** :

| Flow | Fréquence | Horaire | Environnement | Rationale |
|------|-----------|---------|---------------|-----------|
| refill_bucket | Hebdomadaire | Dim 00:00 | N/A | Données fictives : pas besoin de refresh fréquent |
| dbt_full_pipeline | Quotidien | 02:00 | dev | Développement actif : validation quotidienne |
| dbt_full_pipeline | Hebdomadaire | Lun 04:00 | prod | Production : refresh après nouvelles données |

---

## 4. Infrastructure Terraform

### 4.1 Ressources Provisionnées

**Fichier** : `infrastructure/main.tf`

**Ressources Créées** :

```hcl
# 1. Bucket pour le state Terraform (backend)
resource "google_storage_bucket" "terraform_state" {
  name = "test-terraform-473818-tfstate"
  versioning { enabled = true }
  lifecycle { prevent_destroy = true }
}

# 2. Bucket pour les données ingérées (couche Bronze)
resource "google_storage_bucket" "ingested_data" {
  name = "test-terraform-473818-ingested-data"
  location = "europe-west9"
  uniform_bucket_level_access = true
}

# 3. Dataset BigQuery Dev (expérimentation)
resource "google_bigquery_dataset" "dev_dataset" {
  dataset_id = "test_terraform_473818_dev"
  default_table_expiration_ms = 7776000000  # 90 jours
}

# 4. Dataset BigQuery Prod (production)
resource "google_bigquery_dataset" "prod_dataset" {
  dataset_id = "test_terraform_473818_prod"
  # Pas d'expiration : données permanentes
}

# 5. Service Account pour dbt
resource "google_service_account" "dbt_sa" {
  account_id = "test-terraform-473818-sa"
}

# 6. Permissions IAM
resource "google_project_iam_member" "sa_bq_dataeditor" {
  role = "roles/bigquery.dataEditor"  # Créer/modifier tables
}
resource "google_project_iam_member" "sa_bq_jobuser" {
  role = "roles/bigquery.jobUser"     # Exécuter des requêtes
}
resource "google_project_iam_member" "sa_storage_admin" {
  role = "roles/storage.objectAdmin"  # Lire/écrire dans GCS
}
```

### 4.2 Stratégie de Gestion de l'Infrastructure

**Principe Infrastructure as Code (IaC)** :
- Toute l'infrastructure est décrite en code (Terraform)
- Reproductibilité : On peut recréer l'environnement identique
- Versioning : Les changements d'infra sont tracés dans Git
- Collaboration : Revue de code pour les changements d'infra

**Terraform State** :
- Stocké dans GCS (backend "gcs")
- Permet le travail collaboratif (lock distribué)
- Versionné pour rollback en cas d'erreur

**Service Account** :
- Principe du moindre privilège : seulement les rôles nécessaires
- Utilisé par dbt et Prefect pour accéder à BigQuery/GCS
- Credentials stockés dans le bloc Prefect 'gcp-credentials'

---

## 5. Concepts Avancés et Bonnes Pratiques

### 5.1 Pattern ELT vs ETL

**ETL (Extract-Transform-Load)** :
- Transformation AVANT le chargement dans le warehouse
- Outil externe (ex: Talend, Informatica)
- Adapté aux Data Warehouses classiques (coûteux)

**ELT (Extract-Load-Transform)** :
- Transformation APRÈS le chargement (dans le warehouse)
- Exploite la puissance de calcul de BigQuery
- Adapté au Cloud et au Big Data (élasticité)

**Pourquoi ELT pour BigQuery ?**
- BigQuery est massivement parallèle (scan de pétaoctets en secondes)
- Coût optimisé : paiement à la requête (pas de serveur permanent)
- Flexibilité : On peut retraiter les données brutes sans réingestion

### 5.2 Séparation des Couches (Bronze/Silver/Gold)

**Avantages** :
1. **Traçabilité** : On peut toujours remonter aux données brutes
2. **Retraitement** : Si un bug dans les transformations, on rejoueles transformations dbt sans réingérer
3. **Conformité** : Les données brutes sont immuables (audit trail)
4. **Performance** : Les requêtes Power BI tapent sur Gold (optimisé)

**Mapping dans notre architecture** :

| Couche | Emplacement | Outils | Caractéristiques |
|--------|-------------|--------|------------------|
| Bronze | GCS `raw_data/` | seed_script.py + refill_bucket.py | Données brutes, format source (CSV/JSON) |
| Silver | BigQuery `stg_*`, `int_*` | dbt staging + intermediate | Nettoyées, typées, enrichies |
| Gold | BigQuery `dim_*`, `fct_*` | dbt marts | Star schema, optimisé analytics |

### 5.3 Idempotence et Reproductibilité

**Idempotence** : Une opération produit le même résultat si on l'exécute plusieurs fois.

**Dans notre pipeline** :
- `refill_bucket.py` : Upload GCS écrase les fichiers existants (idempotent)
- dbt : Les modèles `materialized='table'` sont recréés à chaque run (idempotent)
- Stratégie incrémentale possible avec `materialized='incremental'` (performance)

**Reproductibilité** :
- Même code + mêmes données → même résultat
- Important pour le debugging et les audits
- Les timestamps dans les données de seed limitent la reproductibilité exacte (trade-off réalisme)

### 5.4 Tests et Qualité des Données

**Tests dbt** :

```yaml
# dbt/models/staging/schema.yml
models:
  - name: stg_viewing_logs
    columns:
      - name: session_id
        tests:
          - unique            # Chaque session est unique
          - not_null          # Pas de session sans ID
      - name: watch_duration_seconds
        tests:
          - positive_values   # Durée > 0
      - name: user_id
        tests:
          - relationships:    # Intégrité référentielle
              to: ref('stg_users')
              field: user_id
```

**Stratégie de Tests** :
1. **Unicité** : Clés primaires (PK) des dimensions
2. **Non-nullité** : Colonnes critiques (IDs, métriques)
3. **Relations** : Clés étrangères (FK) valides
4. **Valeurs Acceptées** : Énumérations (genre, device_type)
5. **Tests Personnalisés** : Règles métier (ex: completion_rate entre 0 et 1)

**Intégration dans le Flow** :
```python
@task test_dbt_models(target)
# Exécute dbt test → échoue si un test échoue
# Permet de bloquer le pipeline en cas de données invalides
```

---

## 6. Prochaines Étapes : Création des Modèles dbt

### 6.1 Checklist pour Développer les Modèles

1. **Définir les Sources** (`dbt/models/staging/sources.yml`)
   - Déclarer les tables externes GCS dans BigQuery
   - Utiliser `dbt source freshness` pour valider la disponibilité

2. **Créer les Modèles Staging** (`dbt/models/staging/`)
   - Un modèle par source (stg_contents, stg_users, etc.)
   - Nettoyage, typage, renommage des colonnes
   - Tests de base (not_null, unique sur les PK)

3. **Créer les Modèles Intermediate** (`dbt/models/intermediate/`)
   - Jointures et enrichissements
   - Calculs métier (completion_rate, etc.)
   - Tests de relations (FK valides)

4. **Créer les Dimensions** (`dbt/models/marts/dimensions/`)
   - Surrogate keys avec `dbt_utils.generate_surrogate_key()`
   - SCD Type 1 (dernière valeur) pour commencer
   - Tests d'unicité sur les SK

5. **Créer la Table de Faits** (`dbt/models/marts/facts/`)
   - Jointures avec les dimensions pour récupérer les SK
   - Métriques agrégées ou calculées
   - Tests de relations vers les dimensions

6. **Documenter** (`dbt/models/marts/schema.yml`)
   - Description de chaque modèle et colonne
   - Tests de qualité des données
   - Génération automatique de documentation : `dbt docs generate`

### 6.2 Configuration dbt à Ajuster

**`dbt/dbt_project.yml`** :

```yaml
models:
  projet_m2_bi:
    staging:
      +materialized: view      # Views pour staging (pas de duplication)
      +schema: staging         # Schema séparé dans BigQuery
    intermediate:
      +materialized: view
      +schema: intermediate
    marts:
      dimensions:
        +materialized: table   # Tables pour marts (performance)
        +schema: marts
      facts:
        +materialized: table
        +schema: marts
```

**Avantages de cette structure** :
- **Views pour staging** : Pas de duplication des données (économie de coût)
- **Tables pour marts** : Performance optimale pour Power BI
- **Schemas séparés** : Organisation logique dans BigQuery

### 6.3 Exemple de Requête Power BI

Une fois les modèles dbt déployés, Power BI se connecte directement au star schema :

```sql
-- Requête Power BI : Top 10 des programmes originaux BigMedia par heures de visionnage
SELECT 
    c.series_name,
    c.genre,
    c.production_type,
    SUM(f.view_duration_minutes) / 60 AS total_hours_watched,
    COUNT(DISTINCT f.user_fk) AS unique_viewers,
    AVG(f.completion_rate) AS avg_completion_rate
FROM `test_terraform_473818_prod.marts.fct_viewings` f
JOIN `test_terraform_473818_prod.marts.dim_content` c 
    ON f.content_fk = c.content_sk
WHERE c.production_type = 'Original BigMedia'
GROUP BY c.series_name, c.genre, c.production_type
ORDER BY total_hours_watched DESC
LIMIT 10
```

**Visuels Power BI Recommandés** :
- Graphique en barres : Comparaison Original vs Achat (heures visionnées)
- Carte : KPIs clés (utilisateurs uniques, heures totales, taux de complétion moyen)
- Line chart : Évolution temporelle du visionnage par genre
- Heatmap : Heures de pointe de visionnage par jour de semaine
- Word cloud : Termes fréquents dans les mentions sociales

---

## 7. Glossaire des Concepts

| Terme | Définition | Exemple dans notre projet |
|-------|------------|---------------------------|
| **ELT** | Extract-Load-Transform : Charger puis transformer dans le warehouse | GCS → BigQuery → dbt |
| **Bronze/Silver/Gold** | Couches de données (brute/nettoyée/analytique) | GCS / staging / marts |
| **Star Schema** | Modèle dimensionnel (1 fact table + N dimensions) | fct_viewings + dim_* |
| **Surrogate Key** | Clé technique générée (indépendante de la clé métier) | content_sk (hash de content_id) |
| **Grain** | Niveau de détail d'une table de faits | 1 ligne = 1 session de visionnage |
| **Idempotence** | Opération produisant le même résultat si répétée | dbt run crée les tables à l'identique |
| **DAG** | Directed Acyclic Graph : graphe de dépendances entre modèles | ref() crée le DAG dbt |
| **Materialization** | Stratégie de stockage (view, table, incremental, ephemeral) | staging=view, marts=table |
| **SCD** | Slowly Changing Dimension : gestion de l'historique des dimensions | Type 1 = dernière valeur |

---

## Résumé des Commandes Utiles

```bash
# === GÉNÉRATION ET INGESTION (Bronze) ===
# Générer et uploader les données brutes
uv run python prefect_flows/refill_bucket.py

# === TRANSFORMATION (Silver + Gold) ===
# Exécuter le pipeline dbt complet (dev)
uv run python prefect_flows/pipeline.py

# Exécuter dbt manuellement (debugging)
cd dbt
dbt run --target dev
dbt test --target dev
dbt docs generate
dbt docs serve  # Documentation interactive

# === PREFECT CLOUD (Production) ===
# Setup des blocs Prefect
uv run python -m infrastructure.setup_profiles --blocks-only

# Déployer le flow d'ingestion
prefect deployment build prefect_flows/refill_bucket.py:refill_bucket_flow -n "refill-bucket" -p default-pool
prefect deployment apply refill_bucket_flow-deployment.yaml

# Déployer le flow dbt
prefect deployment build prefect_flows/pipeline.py:dbt_full_pipeline -n "dbt-dev" -p default-pool --param target=dev
prefect deployment apply dbt_full_pipeline-deployment.yaml

# Exécuter un déploiement
prefect deployment run refill-bucket-flow/refill-bucket
prefect deployment run pipeline-dbt-complet/dbt-dev

# === TERRAFORM (Infrastructure) ===
cd infrastructure
terraform init
terraform plan
terraform apply
terraform output -json > terraform-outputs.json
```

---

## Conclusion

Vous disposez maintenant d'une architecture complète et modulaire pour :
1. Générer des données fictives réalistes (seed_script.py)
2. Les ingérer dans GCS (refill_bucket.py)
3. Les transformer en star schema (dbt + pipeline.py)
4. Les analyser dans Power BI

**Points forts de cette architecture** :
- Séparation claire des responsabilités (génération / ingestion / transformation)
- Résilience (retries, fallbacks, tests)
- Scalabilité (ELT sur BigQuery, orchestration Prefect)
- Maintenabilité (IaC Terraform, documentation dbt)

**Prochaine étape critique** : Créer les modèles dbt dans `dbt/models/` pour matérialiser le star schema décrit dans ce document.

