# Mapping de Données

Ce document décrit le mapping des données depuis les sources brutes jusqu'au modèle en étoile final dans BigQuery. Il détaille les règles de transformation appliquées à chaque étape du pipeline de données, orchestré par Prefect et dbt.

## 1. Mapping : Source vers la Couche Staging (Bronze -> Silver)

La première étape consiste à nettoyer et standardiser les données brutes dans des modèles de "staging" (`stg_*`) dans dbt.

### 1.1. `viewing_logs.json` -> `stg_viewing_logs`

| Champ Source (`viewing_logs.json`) | Champ Cible (`stg_viewing_logs`) | Règle de Transformation                                                                 |
| ---------------------------------- | -------------------------------- | --------------------------------------------------------------------------------------- |
| `session_id`                       | `session_id`                     | Mapping direct.                                                                         |
| `user_id`                          | `user_id`                        | Mapping direct.                                                                         |
| `content_id`                       | `content_id`                     | Mapping direct.                                                                         |
| `start_timestamp`                  | `start_timestamp`                | Conversion en type `TIMESTAMP`.                                                         |
| `end_timestamp`                    | `end_timestamp`                  | Conversion en type `TIMESTAMP`.                                                         |
| `watch_duration_seconds`           | `watch_duration_seconds`         | Mapping direct. Assurer que le type est `INTEGER`.                                      |
| `device_type`                      | `device_type`                    | Nettoyage des valeurs (ex: standardiser "PC" et "computer" en "PC").                      |
| `os`                               | `os`                             | Nettoyage des valeurs (ex: standardiser "Windows" et "windows 11" en "Windows").        |

### 1.2. `contents.csv` -> `stg_contents`

| Champ Source (`contents.csv`) | Champ Cible (`stg_contents`) | Règle de Transformation                               |
| ----------------------------- | ---------------------------- | ----------------------------------------------------- |
| `content_id`                  | `content_id`                 | Mapping direct.                                       |
| `title`                       | `title`                      | Mapping direct.                                       |
| `series_name`                 | `series_name`                | Remplir les valeurs nulles si nécessaire.             |
| `genre`                       | `genre`                      | Standardiser les genres (ex: "Aventure" vs "aventure"). |
| `production_type`             | `production_type`            | Mapping direct.                                       |
| `release_date`                | `release_date`               | Conversion en type `DATE`.                            |

### 1.3. `social_media_mentions.json` -> `stg_social_media`

| Champ Source (`social_media_mentions.json`) | Champ Cible (`stg_social_media`) | Règle de Transformation                                                                                             |
| ------------------------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `mention_id`                                | `mention_id`                     | Mapping direct.                                                                                                     |
| `content_title_mentioned`                   | `content_title_mentioned`        | Nettoyage du texte pour extraire un titre normalisé.                                                                |
| `mention_text`                              | `mention_text`                   | Mapping direct.                                                                                                     |
| `publication_timestamp`                     | `publication_timestamp`          | Conversion en type `TIMESTAMP`.                                                                                     |
| `(mention_text)`                            | `sentiment_score`                | **Logique Complexe** : Application d'un modèle d'analyse de sentiment pour générer un score (Positif, Négatif, Neutre). |

## 2. Mapping : Couche Staging vers la Couche Gold (Silver -> Gold)

La seconde étape consiste à assembler les données de staging pour construire le schéma en étoile final.

### 2.1. Construction de `DIM_Content`

| Table Source (Staging) | Champ Source        | Champ Cible (`DIM_Content`) | Règle de Transformation                                                              |
| ---------------------- | ------------------- | --------------------------- | ------------------------------------------------------------------------------------ |
| `stg_contents`         | `content_id`        | `content_sk`                | Génération d'une clé de substitution (Surrogate Key), par exemple avec `dbt_utils.generate_surrogate_key`. |
| `stg_contents`         | `content_id`        | `content_id`                | Mapping direct (clé métier).                                                         |
| `stg_contents`         | `title`             | `title`                     | Mapping direct.                                                                      |
| `stg_contents`         | `series_name`       | `series_name`               | Mapping direct.                                                                      |
| `stg_contents`         | `genre`             | `genre`                     | Mapping direct.                                                                      |
| `stg_contents`         | `production_type`   | `production_type`           | Mapping direct.                                                                      |
| `stg_contents`         | `release_date`      | `release_year`              | Extraction de l'année à partir de `release_date`.                                    |

### 2.2. Construction de `FCT_Viewings`

C'est la table la plus complexe, qui joint plusieurs tables de staging.

| Table Source (Staging) | Champ Source             | Champ Cible (`FCT_Viewings`) | Règle de Transformation                                                                                                                            |
| ---------------------- | ------------------------ | ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `stg_viewing_logs`     | `session_id`, `user_id`  | `viewing_sk`                 | Génération d'une clé de substitution unique pour l'événement de visionnage.                                                                        |
| `DIM_Users`            | `user_sk`                | `user_fk`                    | Jointure entre `stg_viewing_logs.user_id` et `DIM_Users.user_id` pour récupérer la clé de substitution `user_sk`.                                    |
| `DIM_Content`          | `content_sk`             | `content_fk`                 | Jointure entre `stg_viewing_logs.content_id` et `DIM_Content.content_id` pour récupérer la clé de substitution `content_sk`.                          |
| `DIM_Date`             | `date_sk`                | `date_fk`                    | Jointure sur la date de `stg_viewing_logs.start_timestamp` pour récupérer la clé de substitution `date_sk`.                                         |
| `DIM_Devices`          | `device_sk`              | `device_fk`                  | Jointure sur `stg_viewing_logs.device_type` et `os` pour récupérer la clé de substitution `device_sk`.                                              |
| `stg_viewing_logs`     | `watch_duration_seconds` | `view_duration_minutes`      | Conversion de la durée de secondes en minutes (`watch_duration_seconds` / 60).                                                                     |
| `stg_viewing_logs`, `stg_contents` | `watch_duration_seconds`, `duration_minutes` | `completion_rate` | **Calcul Métier** : (`watch_duration_seconds` / (`stg_contents.duration_minutes` * 60)). Gérer les divisions par zéro. |
| `(completion_rate)`    | `completion_rate`        | `is_completed_view`          | **Logique Métier** : `CASE WHEN completion_rate >= 0.9 THEN TRUE ELSE FALSE END`.                                                                  |
