## 1. Les Données Brutes d'Entrée (Couche "Bronze" dans le Data Lake)

Ces fichiers simulent les différentes sources de données que BigMedia pourrait collecter. Nous allons prévoir un mix de données structurées (CSV) et semi-structurées (JSON) pour bien coller au contexte "Big Data".

#### **Données Internes (issues des systèmes de BigMedia)**

1. **Catalogue de Contenus (`contents.csv`)**  
   * **Description** : Fichier structuré contenant la liste de tous les programmes (séries, épisodes, films d'animation).  
   * **Format** : CSV  
   * **Logique** : Table de référence.  
   * **Colonnes** :  
     * `content_id` (String, PK) : Identifiant unique du contenu. Ex: "anim\_show\_s01e01"  
     * `title` (String) : Titre de l'épisode/film. Ex: "Les aventures de Super-Lapin \- Épisode 1"  
     * `series_name` (String) : Nom de la série. Ex: "Les aventures de Super-Lapin"  
     * `season_number` (Integer) : Numéro de la saison.  
     * `episode_number` (Integer) : Numéro de l'épisode.  
     * `genre` (String) : Genre principal. Ex: "Aventure", "Comédie", "Éducatif"  
     * `target_age_group` (String) : Tranche d'âge cible. Ex: "3-5 ans", "6-8 ans", "9-12 ans"  
     * `production_type` (String) : Type de production. Ex: "**Original BigMedia**", "**Achat**"  
     * `release_date` (Date) : Date de première diffusion.  
     * `duration_minutes` (Integer) : Durée du contenu en minutes.  
2. **Utilisateurs (`users.csv`)**  
   * **Description** : Fichier structuré avec les informations (anonymisées) des utilisateurs inscrits au service VoD.  
   * **Format** : CSV  
   * **Logique** : Table de référence.  
   * **Colonnes** :  
     * `user_id` (String, PK) : Identifiant unique de l'utilisateur.  
     * `registration_date` (Date) : Date d'inscription.  
     * `country` (String) : Pays de l'utilisateur. Ex: "FR", "BE", "CH"  
     * `age_group` (String) : Tranche d'âge de l'utilisateur (déclarative). Ex: "18-24", "25-34" (âge des parents).  
     * `subscription_type` (String) : Dans ce cas, toujours "Gratuit" car le service est gratuit.  
3. **Logs de Visionnage (`viewing_logs.json`)**  
   * **Description** : Fichier semi-structuré qui représente le cœur de l'analyse. Chaque ligne est un événement de visionnage.  
   * **Format** : JSON (une ligne par JSON pour faciliter le streaming et le traitement).  
   * **Logique** : Données transactionnelles, volumineuses.  
   * **Champs** :  
     * `session_id` (String) : ID unique pour une session de visionnage.  
     * `user_id` (String, FK \-\> users) : Qui a regardé.  
     * `content_id` (String, FK \-\> contents) : Qu'est-ce qui a été regardé.  
     * `start_timestamp` (Timestamp) : Quand le visionnage a commencé.  
     * `end_timestamp` (Timestamp) : Quand il s'est terminé.  
     * `watch_duration_seconds` (Integer) : Durée totale regardée en secondes.  
     * `device_type` (String) : Type d'appareil. Ex: "Télévision connectée", "PC", "Smartphone", "Tablette", "Console de jeux"  
     * `os` (String) : Système d'exploitation. Ex: "Android TV", "iOS", "Windows", "Playstation OS"

#### **Données Externes (issues des réseaux sociaux)**

4. **Commentaires et Réactions (`social_media_mentions.json`)**  
   * **Description** : Données non-structurées/semi-structurées collectées sur les réseaux sociaux concernant les productions de BigMedia. C'est une source clé pour répondre à la problématique.  
   * **Format** : JSON (une ligne par JSON).  
   * **Logique** : Données externes, non-structurées.  
   * **Champs** :  
     * `mention_id` (String, PK) : ID unique du post/commentaire.  
     * `content_title_mentioned` (String) : Titre du contenu mentionné (à rapprocher de `contents.csv`).  
     * `platform` (String) : Plateforme d'origine. Ex: "Twitter", "Facebook", "TikTok"  
     * `author_id` (String) : ID (anonymisé) de l'auteur.  
     * `mention_text` (String) : Le texte brut du commentaire. Ex: "Ma fille adore le nouvel épisode de Super-Lapin \! \#BigMedia"  
     * `likes_count` (Integer) : Nombre de "likes".  
     * `shares_count` (Integer) : Nombre de partages.  
     * `publication_timestamp` (Timestamp) : Date et heure de la publication.

---

## 2. Le Modèle Cible en Schéma en Étoile (Couche "Gold" dans BigQuery)

Ce modèle sera la source unique de vérité pour Power BI. Il est optimisé pour l'analyse et la performance.

#### **Table de Faits (Fact Table)**

C'est la table centrale qui contient les métriques quantitatives à analyser.

**`FCT_Viewings`**

* **Description** : Chaque ligne représente un événement de visionnage unique et complet.  
* **Grain** : Une ligne par session de visionnage par utilisateur par contenu.  
* **Colonnes** :  
  * `viewing_sk` (String, PK) : Clé primaire de substitution (Surrogate Key).  
  * `user_fk` (String, FK \-\> DIM\_Users) : Clé étrangère vers la dimension Utilisateurs.  
  * `content_fk` (String, FK \-\> DIM\_Content) : Clé étrangère vers la dimension Contenus.  
  * `date_fk` (Integer, FK \-\> DIM\_Date) : Clé étrangère vers la dimension Date (format YYYYMMDD).  
  * `device_fk` (String, FK \-\> DIM\_Devices) : Clé étrangère vers la dimension Appareils.  
  * `view_duration_minutes` (Float) : **Métrique** \- Durée de visionnage en minutes.  
  * `completion_rate` (Float) : **Métrique** \- Pourcentage du contenu visionné (`watch_duration_seconds` / `total_duration_seconds`).  
  * `is_completed_view` (Boolean) : **Métrique** \- Indicateur (1/0) si le contenu a été vu à plus de 90%.

#### **Tables de Dimensions (Dimension Tables)**

Ces tables décrivent le contexte des faits. Elles contiennent les attributs textuels sur lesquels on va filtrer et agréger.

1. **`DIM_Users`**  
   * **Description** : Informations sur les utilisateurs.  
   * **Colonnes** :  
     * `user_sk` (String, PK) : Clé de substitution.  
     * `user_id` (String) : ID de l'utilisateur (clé métier).  
     * `country` (String).  
     * `age_group` (String).  
     * `days_since_registration` (Integer) : Nombre de jours depuis l'inscription (calculé à la date du jour du chargement).  
2. **`DIM_Content`**  
   * **Description** : Informations sur les programmes.  
   * **Colonnes** :  
     * `content_sk` (String, PK) : Clé de substitution.  
     * `content_id` (String) : ID du contenu (clé métier).  
     * `title` (String).  
     * `series_name` (String).  
     * `genre` (String).  
     * `target_age_group` (String).  
     * `production_type` (String) : **Axe d'analyse crucial** pour comparer les originaux vs. les achats.  
     * `release_year` (Integer).  
3. **`DIM_Devices`**  
   * **Description** : Informations sur les plateformes de visionnage.  
   * **Colonnes** :  
     * `device_sk` (String, PK) : Clé de substitution.  
     * `device_type` (String).  
     * `os` (String).  
4. **`DIM_Date`**  
   * **Description** : Table de date classique pour les analyses temporelles.  
   * **Colonnes** :  
     * `date_sk` (Integer, PK) : Clé de substitution (ex: 20251005).  
     * `full_date` (Date).  
     * `year` (Integer).  
     * `quarter` (Integer).  
     * `month` (Integer).  
     * `day_of_week` (String).  
     * `is_weekend` (Boolean).

---

## 3. Logique de Transformation (Le rôle de dbt)

Votre pipeline dbt aura pour mission de passer des données brutes aux tables du schéma en étoile.

1. **Staging** : Nettoyer et standardiser chaque source brute dans des modèles `stg_*.sql`. (ex: `stg_viewing_logs` qui nettoie les timestamps, `stg_social_media` qui extrait le titre du contenu).  
2. **Analyse de Sentiment** : C'est ici qu'intervient le traitement du Big Data ! Un modèle Python (que vous pouvez orchestrer avec Prefect avant dbt) pourrait lire les `mention_text` de la table de staging des réseaux sociaux, appliquer une analyse de sentiment (Positif, Négatif, Neutre) et stocker le résultat.  
Pour ce POC, une implémentation simplifiée de l'analyse de sentiment sera utilisée, générant des scores aléatoires (0 : négatif, 1 : neutre, 2 : positif).
3. **Dimensions** : Construire les tables `DIM_*` à partir des tables de staging. (ex: `DIM_Content` est construite à partir de `stg_contents`).  
4. **Faits** : Construire la table `FCT_Viewings` en joignant plusieurs tables de staging (`stg_viewing_logs`, `stg_contents`, etc.) pour récupérer les métriques et les clés étrangères vers les dimensions.

---
## 4. KPIs Pertinents pour le Dashboard Power BI
### **\#\# 4\. KPIs Pertinents pour le Dashboard Power BI**

Avec ce modèle, vous pourrez construire des dashboards très riches pour la **Direction de la Programmation** et la **Direction de la Production**.

**Pour la Direction de la Programmation (Stratégie de grille) :**

* **KPIs d'Audience** :  
  * Nombre de spectateurs uniques par programme / par genre.  
  * Heures totales de visionnage par jour / semaine.  
  * Top 10 des programmes les plus vus.  
* **KPIs de Rétention** :  
  * Taux de complétion moyen par série / genre.  
  * Analyse de "binge-watching" (combien d'utilisateurs regardent plusieurs épisodes à la suite).  
* **KPIs de Plateforme** :  
  * Répartition des visionnages par type d'appareil (pour optimiser l'expérience utilisateur).  
  * Heures de pointe de visionnage (pour décider quand lancer de nouveaux épisodes).  
    

**Pour la Direction de la Production (Convaincre d'investir) :**

* **KPIs de Performance des Originaux** :  
  * **Comparaison "Original BigMedia" vs "Achat"** sur tous les KPIs d'audience et de rétention. C'est le graphique clé pour les convaincre \!  
  * Coût par heure de visionnage pour un programme original.  
* **KPIs liés aux Réseaux Sociaux** :  
  * **Corrélation entre le "buzz" social (nombre de mentions, de likes) et le nombre de vues** d'un nouvel épisode original.  
  * **Analyse de Sentiment** : Score de sentiment moyen pour chaque production originale.  
  * Nuage de mots des termes les plus fréquents dans les commentaires pour un show donné.

