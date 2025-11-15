// ===============================================

// PREAMBLE: Document Setup and Styling

// ===============================================



// Set document properties. Using French for proper hyphenation.

#set document(

  title: "POC - Plateforme Big Data BigMedia",

  author: "Groupe de Travail",

)



// Set the main font and size for the document.

#set text(font: "New Computer Modern", size: 11pt, lang: "fr")



// Define the custom blue color used for headings.

#let custom-blue = rgb(1, 41, 105)



// Set the heading numbering format (e.g., 1., 1.1, 1.1.1).

#set heading(numbering: "1.1")



// Define custom styles for level 1 and 2 headings.

// Level 1: e.g., "1. INTRODUCTION" - Bold, Uppercase, Blue, Underlined

#show heading.where(level: 1): it => {

  v(1.8em, weak: true)

  set text(weight: "bold", fill: custom-blue)

  // Reconstruct the heading to make the body uppercase

  let content = [#it.numbering #upper(it.body)]

  underline(content)

  v(0.8em, weak: true)

}



// Level 2: e.g., "1.1 But du document" - Bold, Italic, Blue

#show heading.where(level: 2): it => {

  v(1.5em, weak: true)

  set text(weight: "bold", style: "italic", fill: custom-blue)

  it // 'it' already contains the numbering and body text

  v(0.6em, weak: true)

}



// ===============================================

// TITLE PAGE AND TABLE OF CONTENTS

// Content starts on the same page.

// ===============================================



#align(center)[

  #v(8em)

  #text(16pt, weight: "bold")[POC - Plateforme Big Data BigMedia]

  #v(1.5em)

  #text(14pt, style: "italic")["« Apport du Big Data pour la direction de la programmation d'une chaîne de vidéo à la demande »"]

  #v(4em)

]



// The table of contents appears here, before the main content.

#outline(

  title: align(center)[SOMMAIRE],

  depth: 2, // Show both h1 and h2

  indent: auto

)



#pagebreak()



// ===============================================

// DOCUMENT CONTENT

// ===============================================



= Introduction <intro>

== But du document

Cette fiche a pour but de présenter les spécifications techniques du *Proof of Concept* (POC) pour la future plateforme Big Data de BigMedia. L'objectif de ce POC est de démontrer la faisabilité technique et la valeur métier du projet, afin de valider le concept et de convaincre la direction de la production d'investir dans une solution à plus grande échelle.



= Spécifications techniques <specs>

== Solutions choisies

Le POC évaluera des outils issus des catégories suivantes, identifiées comme nécessaires pour atteindre les objectifs de BigMedia. Les choix technologiques spécifiques seront validés durant cette phase.



- *Collecte et intégration de données (ELT)* : Outils pour extraire les données des systèmes sources (logs, API réseaux sociaux) et les charger dans notre base de données.

  - *Prefect est utilisé pour orchestrer des scripts Python personnalisés qui gèrent l'extraction, le chargement et la transformation des données.*.



- *Stockage Big Data* : Solution capable de stocker des données structurées et non structurées.

  - *Google Cloud Storage (GCS) est utilisé comme Data Lake pour le stockage des données brutes (couche Bronze), et Google BigQuery comme Data Warehouse pour les données modélisées (couche Gold).*



- *Traitement de données* : Transformation des données brut vers des données nettoyées, en schéma en étoile (STAR schema).

  - *Prefect est utilisé pour orchestrer ces workflows dbt, qui sont ensuite exécuté sur BigQuery.*



- *Data Visualisation* : Plateforme pour créer les tableaux de bord et les KPIs à destination des directions métiers.

  - *Power BI est l'outil de BI choisi pour la création des tableaux de bord et la visualisation des KPIs.*

== Architecture technique

L'architecture du POC consiste en un pipeline de données centralisé qui ingère, stocke, traite et présente les données issues des différentes sources. L'accent sera mis sur la capacité à traiter à la fois des données structurées (logs de visionnage) et non structurées (commentaires, likes).



*Description textuelle de l'architecture du POC :*

#align(left)[

  Le pipeline de données est orchestré par *Prefect*. 

  1. Les données brutes (fichiers `JSON` et `CSV`) sont extraites des systèmes sources.

  2. Des scripts Python chargent ces fichiers dans un Data Lake sur *Google Cloud Storage* (couche Bronze).

  3. *dbt* est ensuite utilisé pour transformer, nettoyer et modéliser les données brutes en un schéma en étoile optimisé pour l'analyse.

  4. Les tables transformées (dimensions et faits) sont stockées dans *Google BigQuery* (couche Gold).

  5. Enfin, *Power BI* se connecte à BigQuery pour permettre la visualisation des données et la création de tableaux de bord interactifs pour les équipes métiers.

]



== Fichiers sources

Le périmètre du POC se concentre sur les jeux de données ci-dessous pour illustrer la chaîne de valeur.



#table(

  columns: (auto, auto, auto, auto),

  stroke: (x: 1pt),

  align: (left, left, left, left),

  [*Source*], [*Description*], [*Format*], [*Remarques clés*],

  [`viewing_logs.json`], [Événements de visionnage (session, utilisateur, contenu, appareil).], [JSON (1 événement par ligne)], [Source principale pour les métriques d'audience. Champs en snake_case.],

  [`contents.csv`], [Catalogue de contenus (métadonnées séries/épisodes).], [CSV], [Inclut `duration_minutes` et `production_type` pour les comparaisons Original vs Achat.],

  [`users.csv`], [Profil anonymisé des utilisateurs VoD.], [CSV], [Permet l'analyse par pays, tranche d'âge et ancienneté.],

  [`social_media_mentions.json`], [Mentions issues des réseaux sociaux.], [JSON (1 mention par ligne)], [Score de sentiment simulé pour le POC, futur NLP à intégrer.]

)



== Base de données

La base de données du POC devra stocker les données brutes extraites des sources ainsi que les données nettoyées et agrégées, prêtes pour l'analyse. Une solution flexible sera privilégiée pour s'adapter à la variété des formats.



- *Pour ce POC, nous utilisons Google BigQuery comme système de base de données. Il sert à la fois de destination pour les données transformées par dbt et de source unique de vérité pour l'outil de BI. Sa capacité à gérer de grands volumes de données et son intégration native avec l'écosystème Google Cloud en font un choix pertinent.*



== Modèle de données

Le modèle de données ci-dessous représente la structure cible simplifiée pour les données qui seront exploitées dans le POC. Il se concentre sur les entités clés : utilisateurs, contenus et événements.



#align(center)[

  #image("images/star_schema.png", width: 75%)

]



Faits marquants :

- `FCT_Viewings` porte les métriques telles que la durée de visionnage, le taux de complétion et l'indicateur de visionnage complet.

- Les dimensions apportent le contexte (profil utilisateur, métadonnées contenu, appareil, calendrier) et facilitent les comparaisons Original BigMedia vs Achat.



== Dictionnaire de données

Ce dictionnaire synthétise les champs clés exposés dans la couche Gold et ceux maintenus en staging pour les analyses complémentaires.

#table(
  columns: (auto, auto, auto),
  stroke: (x: 1pt),
  align: (left, left, left),
  [*Table*], [*Nom du champ*], [*Description*],
  [*FCT_Viewings*], `viewing_sk`, `Clé de substitution de l'événement de visionnage`,
  [*FCT_Viewings*], `user_fk`, `Référence à la dimension utilisateur`,
  [*FCT_Viewings*], `content_fk`, `Référence à la dimension contenu`,
  [*FCT_Viewings*], `date_fk`, `Référence à la dimension date (format YYYYMMDD)`,
  [*FCT_Viewings*], `device_fk`, `Référence à la dimension appareil`,
  [*FCT_Viewings*], `view_duration_minutes`, `Durée de visionnage convertie en minutes`,
  [*FCT_Viewings*], `completion_rate`, `Ratio durée visionnée / durée totale du contenu`,
  [*FCT_Viewings*], `is_completed_view`, `Indicateur booléen si le visionnage dépasse 90 % du contenu`,
)

#table(
  columns: (auto, auto, auto),
  stroke: (x: 1pt),
  align: (left, left, left),
  [*Table*], [*Nom du champ*], [*Description*],
  [*DIM_Users*], `user_sk`, `Clé de substitution utilisateur`,
  [*DIM_Users*], `user_id`, `Identifiant métier pseudonymisé`,
  [*DIM_Users*], `country`, `Pays de connexion de l'utilisateur`,
  [*DIM_Users*], `age_group`, `Tranche d'âge déclarée`,
  [*DIM_Users*], `days_since_registration`, `Ancienneté en jours au moment du chargement`,
  [*DIM_Content*], `content_sk`, `Clé de substitution contenu`,
  [*DIM_Content*], `content_id`, `Identifiant métier du contenu`,
  [*DIM_Content*], `title`, `Titre de l'épisode ou du film`,
  [*DIM_Content*], `production_type`, `Origine du contenu (Original BigMedia ou Achat)`,
  [*DIM_Content*], `duration_minutes`, `Durée du contenu en minutes`,
  [*DIM_Devices*], `device_sk`, `Clé de substitution appareil`,
  [*DIM_Devices*], `device_type`, `Catégorie d'appareil (TV, mobile, etc.)`,
  [*DIM_Devices*], `os`, `Système d'exploitation`,
  [*DIM_Date*], `date_sk`, `Clé calendrier (YYYYMMDD)`,
  [*DIM_Date*], `full_date`, `Date complète`,
  [*DIM_Date*], `is_weekend`, `Indicateur fin de semaine`,
)

#table(
  columns: (auto, auto, auto),
  stroke: (x: 1pt),
  align: (left, left, left),
  [*Table staging*], [*Nom du champ*], [*Description*],
  [*STG_Social_Mentions*], `mention_id`, `Identifiant unique de la mention`,
  [*STG_Social_Mentions*], `content_title_mentioned`, `Titre normalisé mentionné dans le message`,
  [*STG_Social_Mentions*], `sentiment_score`, `Score simulé (0: négatif, 1: neutre, 2: positif)`,
  [*STG_Social_Mentions*], `publication_timestamp`, `Horodatage de la publication sur le réseau social`,
)


== Mapping de données
Cette section décrit la correspondance entre les champs des fichiers sources et les champs du modèle de données cible pour le POC.

#table(
  columns: (auto, auto, auto),
  stroke: (x: 1pt),
  align: (left, left, left),
  [*Source brute*], [*Champ cible (staging)*], [*Règle de transformation*],
  [`viewing_logs.json.user_id`], `stg_viewing_logs.user_id`, `Mapping direct (snake_case conservé)`,
  [`viewing_logs.json.content_id`], `stg_viewing_logs.content_id`, `Mapping direct`,
  [`viewing_logs.json.watch_duration_seconds`], `stg_viewing_logs.watch_duration_seconds`, `Mapping direct (type INTEGER)`,
  [`viewing_logs.json.start_timestamp`], `stg_viewing_logs.start_timestamp`, `Conversion au format TIMESTAMP BigQuery`,
  [`contents.csv.duration_minutes`], `stg_contents.duration_minutes`, `Mapping direct (type INTEGER)`,
  [`users.csv.registration_date`], `stg_users.registration_date`, `Conversion au format DATE`,
  [`users.csv.country`], `stg_users.country`, `Standardisation des codes pays (FR, BE, CH)`,
  [`social_media_mentions.json.mention_text`], `stg_social_media.mention_text`, `Nettoyage minimal (trim, suppression HTML)`,
  [`social_media_mentions.json.mention_text`], `stg_social_media.sentiment_score`, `Simulation d'un score 0/1/2 en attendant une librairie NLP`,
)

#table(
  columns: (auto, auto, auto),
  stroke: (x: 1pt),
  align: (left, left, left),
  [*Staging*], [*Champ cible (Gold)*], [*Règle de transformation*],
  [`stg_viewing_logs.session_id`], `FCT_Viewings.viewing_sk`, `Génération d'une clé de substitution (combinaison session_id + user_id)`,
  [`stg_viewing_logs.user_id`], `FCT_Viewings.user_fk`, `Jointure sur DIM_Users.user_id`,
  [`stg_viewing_logs.content_id`], `FCT_Viewings.content_fk`, `Jointure sur DIM_Content.content_id`,
  [`stg_viewing_logs.start_timestamp`], `FCT_Viewings.date_fk`, `Dérivation de la date YYYYMMDD et jointure sur DIM_Date`,
  [`stg_viewing_logs.device_type`], `FCT_Viewings.device_fk`, `Jointure sur DIM_Devices (device_type + os)`,
  [`stg_viewing_logs.os`], `DIM_Devices.os`, `Standardisation des libellés systèmes (Android TV, iOS, etc.)`,
  [`stg_viewing_logs.watch_duration_seconds`], `FCT_Viewings.view_duration_minutes`, `Division par 60 et arrondi à deux décimales`,
  [`stg_viewing_logs.watch_duration_seconds`], `FCT_Viewings.completion_rate`, `watch_duration_seconds / (stg_contents.duration_minutes * 60) avec gestion division par zéro`,
  [`FCT_Viewings.completion_rate`], `FCT_Viewings.is_completed_view`, `CASE WHEN completion_rate >= 0.9 THEN TRUE ELSE FALSE END`,
)

= Annexe <annexe>
// Contenu de l'annexe à ajouter si nécessaire.