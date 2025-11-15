# Dictionnaire de Données : KPIs et Dimensions

Ce document définit les indicateurs de performance clés (KPIs) et les dimensions utilisées pour l'analyse de la plateforme BigMedia. Il sert de référence pour les équipes métiers et techniques afin de garantir une compréhension commune des données présentées dans les tableaux de bord.

## 1. Dimensions

Les dimensions fournissent le contexte descriptif pour l'analyse des données. Elles correspondent aux axes sur lesquels les métriques peuvent être filtrées et agrégées.

### 1.1. DIM_Users
Informations sur les utilisateurs du service VoD.

| Nom du champ              | Description                                                 | Exemple         |
| ------------------------- | ----------------------------------------------------------- | --------------- |
| `user_sk`                 | Clé de substitution unique pour l'utilisateur.              | `USR12345`      |
| `user_id`                 | Identifiant métier de l'utilisateur.                        | `user_abc`      |
| `country`                 | Pays de l'utilisateur.                                      | `FR`, `BE`, `CH` |
| `age_group`               | Tranche d'âge déclarative (des parents).                    | `25-34`         |
| `days_since_registration` | Nombre de jours depuis l'inscription de l'utilisateur.      | `365`           |

### 1.2. DIM_Content
Informations sur les contenus disponibles sur la plateforme.

| Nom du champ         | Description                                                              | Exemple                        |
| -------------------- | ------------------------------------------------------------------------ | ------------------------------ |
| `content_sk`         | Clé de substitution unique pour le contenu.                              | `CNT67890`                     |
| `content_id`         | Identifiant métier du contenu.                                           | `anim_show_s01e01`             |
| `title`              | Titre de l'épisode ou du film.                                           | `Les aventures de Super-Lapin` |
| `series_name`        | Nom de la série.                                                         | `Les aventures de Super-Lapin` |
| `genre`              | Genre principal du contenu.                                              | `Aventure`, `Comédie`          |
| `target_age_group`   | Tranche d'âge cible pour le contenu.                                     | `3-5 ans`                      |
| `production_type`    | Type de production. Axe d'analyse clé.                                   | `Original BigMedia`, `Achat`   |
| `release_year`       | Année de première diffusion.                                             | `2024`                         |

### 1.3. DIM_Devices
Informations sur les appareils utilisés pour le visionnage.

| Nom du champ  | Description                                  | Exemple                 |
| ------------- | -------------------------------------------- | ----------------------- |
| `device_sk`   | Clé de substitution unique pour l'appareil.  | `DEV54321`              |
| `device_type` | Type d'appareil.                             | `Télévision connectée`  |
| `os`          | Système d'exploitation de l'appareil.        | `Android TV`, `iOS`     |

### 1.4. DIM_Date
Table de calendrier pour les analyses temporelles.

| Nom du champ  | Description                                  | Exemple      |
| ------------- | -------------------------------------------- | ------------ |
| `date_sk`     | Clé de substitution unique pour la date (YYYYMMDD). | `20251109`   |
| `full_date`   | Date complète.                               | `2025-11-09` |
| `year`        | Année.                                       | `2025`       |
| `quarter`     | Trimestre.                                   | `4`          |
| `month`       | Mois.                                        | `11`         |
| `day_of_week` | Jour de la semaine.                          | `Dimanche`   |
| `is_weekend`  | Indicateur de week-end (Vrai/Faux).          | `Vrai`       |

## 2. Indicateurs de Performance Clés (KPIs)

Les KPIs sont des métriques quantifiables utilisées pour évaluer la performance et l'engagement sur la plateforme.

### 2.1. KPIs d'Audience
*   **Nombre de spectateurs uniques** : Nombre total d'utilisateurs distincts ayant visionné un contenu sur une période donnée.
*   **Heures totales de visionnage** : Somme des durées de visionnage de tous les utilisateurs.
*   **Top 10 des programmes les plus vus** : Classement des contenus basé sur le nombre de spectateurs uniques ou les heures de visionnage.

### 2.2. KPIs de Rétention
*   **Taux de complétion moyen** : Pourcentage moyen d'un contenu qui est visionné (`view_duration_minutes` / `content_duration_minutes`).
*   **Analyse de "binge-watching"** : Nombre d'utilisateurs regardant plusieurs épisodes d'une même série consécutivement.
*   **Taux de retour** : Fréquence à laquelle les utilisateurs reviennent sur la plateforme.

### 2.3. KPIs de Plateforme
*   **Répartition des visionnages par appareil** : Distribution des sessions de visionnage entre les différents types d'appareils (TV, mobile, etc.).
*   **Heures de pointe de visionnage** : Périodes de la journée ou de la semaine avec le plus grand nombre de spectateurs actifs.

### 2.4. KPIs de Performance des Productions Originales
*   **Comparaison "Original BigMedia" vs "Achat"** : Analyse comparative des KPIs d'audience et de rétention entre les productions internes et les contenus achetés.
*   **Coût par heure de visionnage** : Ratio entre le coût de production d'un contenu original et le nombre total d'heures visionnées.

### 2.5. KPIs liés aux Réseaux Sociaux
*   **Corrélation Buzz vs. Vues** : Analyse de la relation entre le volume de mentions sur les réseaux sociaux et l'audience d'un programme.
*   **Score de sentiment moyen** : Note moyenne (positive, négative, neutre) des commentaires sur les réseaux sociaux pour un contenu donné.
*   **Nuage de mots** : Visualisation des termes les plus fréquents dans les discussions en ligne concernant un programme.
