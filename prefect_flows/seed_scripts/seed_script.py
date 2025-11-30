import pandas as pd
from faker import Faker
import random
import json
import uuid
from datetime import datetime, timedelta
import os
import utility_functions

# Initialisation de Faker pour générer des données en français
fake = Faker('fr_FR')

# --- CONFIGURATION ---
# Définissez ici le nombre d'enregistrements à générer pour chaque fichier
NUM_SERIES = 30  # Nombre de séries différentes
NUM_CONTENTS = 135  # Nombre total d'épisodes
NUM_USERS = 1500
NUM_VIEWING_LOGS = 45000
NUM_SOCIAL_MENTIONS = 2400
OUTPUT_DIR = "raw_data"  # Dossier où les fichiers seront sauvegardés
STATIC_DATA_PATH = os.path.join(OUTPUT_DIR, "static_data", "movies_and_series_titles.csv")

# Listes de valeurs prédéfinies pour la cohérence des données
GENRES = ["Action", "Aventure", "Comédie", "Éducatif", "Science-Fiction", "Fantaisie", "Documentaire"]
AGE_GROUPS_CONTENT = ["3-5 ans", "6-8 ans", "9-12 ans", "13-17 ans", "18-24 ans", "25-34 ans", "35-44 ans", "45-54 ans"]
PRODUCTION_TYPES = ["Original BigMedia", "Achat"]
PLATFORMS = ["Twitter", "Facebook", "TikTok", "Instagram"]


def generate_contents(n: int) -> tuple[pd.DataFrame, dict, list]:
    """
    Génère un catalogue de contenus fictifs avec cohérence des attributs par série.

    Args:
        n (int): Le nombre de contenus (épisodes) à générer.

    Returns:
        tuple: Un DataFrame pandas des contenus, un dictionnaire {content_id: duration},
               et une liste des titres de contenu.
    """
    print(f"Génération de {n} contenus répartis sur {NUM_SERIES} séries...")
    
    # Étape 1 : Charger les noms de séries depuis le fichier CSV statique
    series_names = utility_functions.load_series_names_from_csv(STATIC_DATA_PATH, NUM_SERIES)
    
    # Si le chargement échoue ou donne trop peu de séries, créer des noms génériques
    if len(series_names) < NUM_SERIES:
        print(f"Seulement {len(series_names)} séries chargées depuis le CSV, génération de noms supplémentaires...")
        additional_names = [f"Les Chroniques de {fake.word().capitalize()}" for _ in range(NUM_SERIES - len(series_names))]
        series_names.extend(additional_names)
    
    # Étape 2 : Créer les "séries mères" avec leurs attributs fixes
    series_metadata = {}
    for series_name in series_names:
        production_type = random.choice(PRODUCTION_TYPES)
        series_metadata[series_name] = {
            "genre": random.choice(GENRES),
            "target_age_group": random.choice(AGE_GROUPS_CONTENT),
            "production_type": production_type,
            # Plage de coût cohérente pour toute la série
            "cost_min": 50000 if production_type == "Original BigMedia" else 10000,
            "cost_max": 200000 if production_type == "Original BigMedia" else 50000,
            # Date de sortie de la série (première saison)
            "series_start_date": fake.date_between(start_date='-2y', end_date='-6m')
        }
    
    # Étape 3 : Générer les épisodes en respectant les attributs de chaque série
    contents_data = []
    episodes_per_series = n // NUM_SERIES
    remainder = n % NUM_SERIES
    
    episode_counter = 0
    for idx, series_name in enumerate(series_names):
        metadata = series_metadata[series_name]
        
        # Certaines séries auront un épisode de plus pour atteindre exactement n épisodes
        num_episodes = episodes_per_series + (1 if idx < remainder else 0)
        
        # Répartir les épisodes sur plusieurs saisons
        num_seasons = random.randint(1, 3)
        episodes_per_season = num_episodes // num_seasons
        
        for season in range(1, num_seasons + 1):
            # Nombre d'épisodes dans cette saison
            season_episodes = episodes_per_season
            if season == num_seasons:
                # La dernière saison prend les épisodes restants
                season_episodes = num_episodes - (episodes_per_season * (num_seasons - 1))
            
            for episode in range(1, season_episodes + 1):
                # Durée variable par épisode (15-45 minutes)
                duration = random.randint(15, 45)
                
                # Coût de production variable par épisode, mais dans la plage de la série
                production_cost = random.randint(metadata["cost_min"], metadata["cost_max"])
                
                # Date de sortie : progressive pour chaque saison
                release_date = metadata["series_start_date"] + timedelta(days=(season - 1) * 30 + episode * 7)
                
                # Identifiant unique et normalisé
                content_id = f"{series_name.lower().replace(' ', '_').replace(',', '').replace(':', '')}_s{season:02d}e{episode:02d}"
                
                contents_data.append({
                    "content_id": content_id,
                    "title": f"{series_name} - S{season:02d}E{episode:02d}",
                    "series_name": series_name,
                    "season_number": season,
                    "episode_number": episode,
                    "genre": metadata["genre"],
                    "target_age_group": metadata["target_age_group"],
                    "production_type": metadata["production_type"],
                    "release_date": release_date,
                    "duration_minutes": duration,
                    "production_cost_euros": production_cost
                })
                
                episode_counter += 1
    
    df = pd.DataFrame(contents_data)
    
    # Pour la cohérence, on s'assure que les content_id sont uniques
    df = df.drop_duplicates(subset=['content_id'])
    
    content_durations = pd.Series(df.duration_minutes.values, index=df.content_id).to_dict()
    content_titles = df['title'].tolist()
    
    # Créer un mapping content_id -> title pour les mentions sur les réseaux sociaux
    content_mapping = df[['content_id', 'title']].to_dict('records')
    
    print(f"  → {len(df)} épisodes générés sur {NUM_SERIES} séries")
    
    return df, content_durations, content_titles, content_mapping


def generate_users(n: int) -> tuple[pd.DataFrame, list]:
    """
    Génère une liste d'utilisateurs fictifs.

    Args:
        n (int): Le nombre d'utilisateurs à générer.

    Returns:
        tuple: Un DataFrame pandas des utilisateurs et une liste de leurs IDs.
    """
    print(f"Génération de {n} utilisateurs...")
    
    users_data = []
    for _ in range(n):
        age = utility_functions.generate_age()
        country = utility_functions.generate_country()
        
        users_data.append({
            "user_id": str(uuid.uuid4()),
            "registration_date": fake.date_between(start_date='-3y', end_date='today'),
            "country": country,
            "age": age,
            "subscription_type": "Gratuit"
        })
    df = pd.DataFrame(users_data)
    user_ids = df['user_id'].tolist()
    
    print(f"  → {len(df)} utilisateurs générés")
    
    return df, user_ids


def generate_viewing_logs(n: int, user_ids: list, content_durations: dict) -> list[dict]:
    """
    Génère des logs de visionnage avec des comportements de binge-watching réalistes.
    
    Environ 8% des logs sont générés en sessions de binge-watching (3-6 épisodes
    d'une même série regardés le même jour), le reste sont des visionnages normaux
    aléatoires.

    Args:
        n (int): Le nombre de logs à générer.
        user_ids (list): La liste des user_id valides.
        content_durations (dict): Dictionnaire mappant content_id à sa durée.

    Returns:
        list[dict]: Une liste de dictionnaires, chaque dictionnaire étant un log.
    """
    print(f"Génération de {n} logs de visionnage avec comportements de binge-watching...")
    logs_data = []
    content_ids = list(content_durations.keys())
    
    # Grouper les contenus par série
    series_episodes = utility_functions.group_content_by_series(content_durations)
    
    # Récupérer les combinaisons valides de device_type et OS
    device_os_combinations = utility_functions.get_valid_device_os_combinations()
    
    # Plage temporelle : le mois dernier
    end_date = datetime.now()
    start_date = end_date - timedelta(days=90)
    
    # Configuration : environ 8% des logs en binge-watching
    # Une session de binge = 3-6 épisodes, moyenne de 4
    binge_ratio = 0.08
    avg_episodes_per_binge = 4
    num_binge_sessions = int((n * binge_ratio) / avg_episodes_per_binge)
    
    logs_generated = 0
    
    # 1. Générer les sessions de binge-watching
    print(f"  → Génération de {num_binge_sessions} sessions de binge-watching...")
    binge_sessions_created = 0
    
    for _ in range(num_binge_sessions):
        if logs_generated >= n:
            break
        
        # Choisir un utilisateur et une série
        user_id = random.choice(user_ids)
        series_name = random.choice(list(series_episodes.keys()))
        episodes = series_episodes[series_name]
        
        # Générer la session de binge-watching
        session_logs = utility_functions.generate_binge_watching_session(
            user_id=user_id,
            series_name=series_name,
            episodes=episodes,
            content_durations=content_durations,
            start_date=start_date,
            end_date=end_date,
            device_os_combinations=device_os_combinations
        )
        
        logs_data.extend(session_logs)
        logs_generated += len(session_logs)
        binge_sessions_created += 1
    
    print(f"     - {binge_sessions_created} sessions créées ({logs_generated} logs)")
    
    # 2. Compléter avec des visionnages normaux (aléatoires)
    normal_logs_to_generate = n - logs_generated
    print(f"  → Génération de {normal_logs_to_generate} visionnages normaux...")
    
    for _ in range(normal_logs_to_generate):
        user_id = random.choice(user_ids)
        content_id = random.choice(content_ids)
        total_duration_sec = content_durations[content_id] * 60
        
        # Pour les visionnages normaux, taux de complétion variable (10% à 100%)
        completion_rate = random.uniform(0.1, 1.0)
        watch_duration_sec = int(total_duration_sec * completion_rate)
        watch_duration_sec = max(30, watch_duration_sec)  # Au moins 30s
        
        start_time = fake.date_time_between(start_date=start_date, end_date=end_date)
        end_time = start_time + timedelta(seconds=watch_duration_sec)
        
        # Choisir une combinaison cohérente device/OS
        device_os = random.choice(device_os_combinations)
        
        logs_data.append({
            "session_id": str(uuid.uuid4()),
            "user_id": user_id,
            "content_id": content_id,
            "start_timestamp": start_time.isoformat(),
            "end_timestamp": end_time.isoformat(),
            "watch_duration_seconds": watch_duration_sec,
            "device_type": device_os["device_type"],
            "os": device_os["os"]
        })
        logs_generated += 1
    
    print(f"  → Total: {len(logs_data)} logs générés")
    print(f"     • Sessions de binge-watching: ~{int((binge_sessions_created * avg_episodes_per_binge / len(logs_data)) * 100)}%")
    print(f"     • Visionnages normaux: ~{int((normal_logs_to_generate / len(logs_data)) * 100)}%")
    
    return logs_data


def generate_social_media_mentions(n: int, content_mapping: list[dict]) -> list[dict]:
    """
    Génère des mentions fictives sur les réseaux sociaux.

    Args:
        n (int): Le nombre de mentions à générer.
        content_mapping (list[dict]): Liste de dictionnaires avec 'content_id' et 'title'.

    Returns:
        list[dict]: Une liste de dictionnaires, chaque dictionnaire étant une mention.
    """
    print(f"Génération de {n} mentions sur les réseaux sociaux...")
    mentions_data = []
    
    # Plage temporelle : le mois dernier
    end_date = datetime.now()
    start_date = end_date - timedelta(days=90)

    comment_templates = [
        "Mon fils adore {title} ! C'est sa nouvelle série préférée.",
        "Franchement, {title} est incroyable. Bravo à l'équipe de #BigMedia",
        "Un peu déçu par le dernier épisode de {title}...",
        "Quand est-ce que la nouvelle saison de {title} sort ?? On attend !",
        "Super découverte sur BigMedia : {title}. Je recommande à tous les parents.",
        "Les animations de {title} sont magnifiques !"
    ]
    
    for _ in range(n):
        # Sélectionner un contenu aléatoire avec son content_id et son titre
        content = random.choice(content_mapping)
        content_id = content['content_id']
        title = content['title']

        mentions_data.append({
            "mention_id": str(uuid.uuid4()),
            "content_id": content_id,
            "content_title_mentioned": title,
            "platform": random.choice(PLATFORMS),
            "author_id": str(uuid.uuid4()),
            "mention_text": random.choice(comment_templates).format(title=title),
            "likes_count": random.randint(0, 500),
            "shares_count": random.randint(0, 100),
            "publication_timestamp": fake.date_time_between(start_date=start_date, end_date=end_date).isoformat()
        })
    
    print(f"  → {len(mentions_data)} mentions générées")
    
    return mentions_data

# --- FONCTIONS DE SAUVEGARDE ---

def save_to_csv(df: pd.DataFrame, path: str):
    """Sauvegarde un DataFrame en fichier CSV."""
    df.to_csv(path, index=False, encoding='utf-8-sig')
    print(f"Fichier sauvegardé : {path}")

def save_to_json_lines(data: list[dict], path: str):
    """Sauvegarde une liste de dictionnaires en fichier JSON Lines."""
    with open(path, 'w', encoding='utf-8') as f:
        for item in data:
            f.write(json.dumps(item, ensure_ascii=False) + '\n')
    print(f"Fichier sauvegardé : {path}")


# --- SCRIPT PRINCIPAL ---

def main():
    """
    Orchestre la génération et la sauvegarde de toutes les données brutes.
    """
    # Crée le dossier de sortie s'il n'existe pas
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # 1. Générer les données "parent" (celles dont les autres dépendent)
    contents_df, content_durations, content_titles, content_mapping = generate_contents(NUM_CONTENTS)
    users_df, user_ids = generate_users(NUM_USERS)

    # 2. Générer les données "enfant" en utilisant les IDs et titres des parents
    #    Ceci garantit la cohérence et l'intégrité référentielle !
    viewing_logs = generate_viewing_logs(NUM_VIEWING_LOGS, user_ids, content_durations)
    social_mentions = generate_social_media_mentions(NUM_SOCIAL_MENTIONS, content_mapping)

    # 3. Sauvegarder tous les fichiers
    print("\n--- Sauvegarde des fichiers ---")
    save_to_csv(contents_df, os.path.join(OUTPUT_DIR, "contents.csv"))
    save_to_csv(users_df, os.path.join(OUTPUT_DIR, "users.csv"))
    save_to_json_lines(viewing_logs, os.path.join(OUTPUT_DIR, "viewing_logs.json"))
    save_to_json_lines(social_mentions, os.path.join(OUTPUT_DIR, "social_media_mentions.json"))
    
    print("\nGénération des données terminée avec succès !")


if __name__ == "__main__":
    main()