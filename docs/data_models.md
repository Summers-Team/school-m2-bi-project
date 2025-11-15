# Modèles de Données (MCD & MPD)

Ce document présente le Modèle Conceptuel de Données (MCD) et le Modèle Physique de Données (MPD) pour la plateforme Big Data de BigMedia, représentés à l'aide de diagrammes Mermaid.

## 1. Modèle Conceptuel de Données (MCD)

Le MCD représente les entités métiers principales et leurs relations logiques. Il se concentre sur la sémantique des données avant toute considération technique.

```mermaid
erDiagram
    USER ||--o{ VIEWING_EVENT : "effectue"
    CONTENT ||--o{ VIEWING_EVENT : "est l'objet de"
    DEVICE ||--o{ VIEWING_EVENT : "est utilisé pour un"
    CONTENT ||--o{ SOCIAL_MENTION : "est mentionné dans une"

    USER {
        string user_id "Identifiant unique"
        date registration_date "Date d'inscription"
        string country "Pays"
        string age_group "Tranche d'âge"
    }

    CONTENT {
        string content_id "Identifiant unique"
        string title "Titre"
        string series_name "Nom de la série"
        string genre "Genre"
        string production_type "Type (Original/Achat)"
    }

    VIEWING_EVENT {
        string session_id "Identifiant de session"
        timestamp start_timestamp "Début du visionnage"
        timestamp end_timestamp "Fin du visionnage"
        int watch_duration_seconds "Durée en secondes"
    }

    DEVICE {
        string device_type "Type d'appareil"
        string os "Système d'exploitation"
    }

    SOCIAL_MENTION {
        string mention_id "Identifiant unique"
        string platform "Réseau social"
        string mention_text "Texte du commentaire"
        int likes_count "Nombre de likes"
    }
```

## 2. Modèle Physique de Données (MPD) - Schéma en Étoile

Le MPD décrit la structure physique des tables dans la base de données (Google BigQuery). Il est optimisé pour l'analyse décisionnelle (BI) et suit un modèle en étoile.

*   **Table de Faits (`FCT_Viewings`)** : Contient les métriques à analyser (ex: durée de visionnage).
*   **Tables de Dimensions (`DIM_*`)** : Contiennent les axes d'analyse (ex: utilisateur, contenu, temps).

```mermaid
erDiagram
    FCT_Viewings }o--|| DIM_Users : "concerne"
    FCT_Viewings }o--|| DIM_Content : "concerne"
    FCT_Viewings }o--|| DIM_Date : "a lieu à"
    FCT_Viewings }o--|| DIM_Devices : "se fait sur"

    FCT_Viewings {
        string viewing_sk PK "Clé de substitution du visionnage"
        string user_fk FK "Clé étrangère vers DIM_Users"
        string content_fk FK "Clé étrangère vers DIM_Content"
        int date_fk FK "Clé étrangère vers DIM_Date"
        string device_fk FK "Clé étrangère vers DIM_Devices"
        float view_duration_minutes "Métrique: Durée en minutes"
        float completion_rate "Métrique: Taux de complétion"
        bool is_completed_view "Métrique: Visionnage complet"
    }

    DIM_Users {
        string user_sk PK "Clé de substitution"
        string user_id "Clé métier"
        string country "Pays"
        string age_group "Tranche d'âge"
        int days_since_registration "Jours depuis l'inscription"
    }

    DIM_Content {
        string content_sk PK "Clé de substitution"
        string content_id "Clé métier"
        string title "Titre"
        string series_name "Nom de la série"
        string genre "Genre"
        string target_age_group "Âge cible"
        string production_type "Type de production"
        int release_year "Année de sortie"
    }

    DIM_Devices {
        string device_sk PK "Clé de substitution"
        string device_type "Type d'appareil"
        string os "Système d'exploitation"
    }

    DIM_Date {
        int date_sk PK "Clé de substitution (YYYYMMDD)"
        date full_date "Date complète"
        int year "Année"
        int quarter "Trimestre"
        int month "Mois"
        string day_of_week "Jour de la semaine"
        bool is_weekend "Indicateur de week-end"
    }
```
