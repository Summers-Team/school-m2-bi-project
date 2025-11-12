import pandas as pd
from faker import Faker
import random
import json
import uuid
from datetime import datetime, timedelta
import os

# Initialisation de Faker pour générer des données en français
fake = Faker('fr_FR')

# --- CONFIGURATION ---
# Définissez ici le nombre d'enregistrements à générer pour chaque fichier
NUM_CONTENTS = 50
NUM_USERS = 500
NUM_VIEWING_LOGS = 10000
NUM_SOCIAL_MENTIONS = 2000
OUTPUT_DIR = "raw_data" # Dossier où les fichiers seront sauvegardés

# Listes de valeurs prédéfinies pour la cohérence des données
GENRES = ["Aventure", "Comédie", "Éducatif", "Science-Fiction", "Fantaisie"]
AGE_GROUPS_CONTENT = ["3-5 ans", "6-8 ans", "9-12 ans"]
AGE_GROUPS_USERS = ["18-24", "25-34", "35-44", "45-54"]
PRODUCTION_TYPES = ["Original BigMedia", "Achat"]
DEVICE_TYPES = ["Télévision connectée", "PC", "Smartphone", "Tablette", "Console de jeux"]
OS_LIST = ["Android TV", "iOS", "Windows", "Playstation OS", "Tizen", "WebOS"]
PLATFORMS = ["Twitter", "Facebook", "TikTok", "Instagram"]

# --- FONCTIONS DE GÉNÉRATION DE DONNÉES ---

def generate_contents(n: int) -> tuple[pd.DataFrame, dict, list]:
    """
    Génère un catalogue de contenus fictifs.

    Args:
        n (int): Le nombre de contenus à générer.

    Returns:
        tuple: Un DataFrame pandas des contenus, un dictionnaire {content_id: duration},
               et une liste des titres de contenu.
    """
    print(f"Génération de {n} contenus...")
    contents_data = []
    series_names = [f"Les Chroniques de {fake.word().capitalize()}" for _ in range(n // 5)]

    for i in range(n):
        series = random.choice(series_names)
        season = random.randint(1, 3)
        episode = random.randint(1, 10)
        duration = random.randint(15, 45)
        production_type = random.choice(PRODUCTION_TYPES)
        
        # Générer des coûts réalistes : Originaux plus chers que les Achats
        if production_type == "Original BigMedia":
            # Coûts pour originaux : entre 50000 et 200000 euros
            production_cost = random.randint(50000, 200000)
        else:
            # Coûts pour achats : entre 10000 et 50000 euros
            production_cost = random.randint(10000, 50000)
        
        contents_data.append({
            "content_id": f"{series.lower().replace(' ', '_')}_s{season:02d}e{episode:02d}_{i}",
            "title": f"{series} - S{season:02d}E{episode:02d}",
            "series_name": series,
            "season_number": season,
            "episode_number": episode,
            "genre": random.choice(GENRES),
            "target_age_group": random.choice(AGE_GROUPS_CONTENT),
            "production_type": production_type,
            "release_date": fake.date_between(start_date='-2y', end_date='today'),
            "duration_minutes": duration,
            "production_cost_euros": production_cost
        })
    
    df = pd.DataFrame(contents_data)
    # Pour la cohérence, on s'assure que les content_id sont uniques
    df = df.drop_duplicates(subset=['content_id'])
    
    content_durations = pd.Series(df.duration_minutes.values, index=df.content_id).to_dict()
    content_titles = df['title'].tolist()
    
    return df, content_durations, content_titles


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
        users_data.append({
            "user_id": str(uuid.uuid4()),
            "registration_date": fake.date_between(start_date='-3y', end_date='today'),
            "country": random.choice(["FR", "BE", "CH", "LU"]),
            "age_group": random.choice(AGE_GROUPS_USERS),
            "subscription_type": "Gratuit"
        })
    df = pd.DataFrame(users_data)
    user_ids = df['user_id'].tolist()
    return df, user_ids


def generate_viewing_logs(n: int, user_ids: list, content_durations: dict) -> list[dict]:
    """
    Génère des logs de visionnage en se basant sur les utilisateurs et contenus existants.

    Args:
        n (int): Le nombre de logs à générer.
        user_ids (list): La liste des user_id valides.
        content_durations (dict): Dictionnaire mappant content_id à sa durée.

    Returns:
        list[dict]: Une liste de dictionnaires, chaque dictionnaire étant un log.
    """
    print(f"Génération de {n} logs de visionnage...")
    logs_data = []
    content_ids = list(content_durations.keys())
    
    # Plage temporelle : le mois dernier
    end_date = datetime.now()
    start_date = end_date - timedelta(days=30)
    
    for _ in range(n):
        content_id = random.choice(content_ids)
        total_duration_sec = content_durations[content_id] * 60
        watch_duration_sec = random.randint(30, total_duration_sec) # Au moins 30s de visionnage
        
        start_time = fake.date_time_between(start_date=start_date, end_date=end_date)
        end_time = start_time + timedelta(seconds=watch_duration_sec)
        
        logs_data.append({
            "session_id": str(uuid.uuid4()),
            "user_id": random.choice(user_ids),
            "content_id": content_id,
            "start_timestamp": start_time.isoformat(),
            "end_timestamp": end_time.isoformat(),
            "watch_duration_seconds": watch_duration_sec,
            "device_type": random.choice(DEVICE_TYPES),
            "os": random.choice(OS_LIST)
        })
    return logs_data


def generate_social_media_mentions(n: int, content_titles: list) -> list[dict]:
    """
    Génère des mentions fictives sur les réseaux sociaux.

    Args:
        n (int): Le nombre de mentions à générer.
        content_titles (list): La liste des titres de contenu à mentionner.

    Returns:
        list[dict]: Une liste de dictionnaires, chaque dictionnaire étant une mention.
    """
    print(f"Génération de {n} mentions sur les réseaux sociaux...")
    mentions_data = []
    
    # Plage temporelle : le mois dernier
    end_date = datetime.now()
    start_date = end_date - timedelta(days=30)

    comment_templates = [
        "Mon fils adore {title} ! C'est sa nouvelle série préférée.",
        "Franchement, {title} est incroyable. Bravo à l'équipe de #BigMedia",
        "Un peu déçu par le dernier épisode de {title}...",
        "Quand est-ce que la nouvelle saison de {title} sort ?? On attend !",
        "Super découverte sur BigMedia : {title}. Je recommande à tous les parents.",
        "Les animations de {title} sont magnifiques !"
    ]
    
    for _ in range(n):
        title = random.choice(content_titles)
        mentions_data.append({
            "mention_id": str(uuid.uuid4()),
            "content_title_mentioned": title,
            "platform": random.choice(PLATFORMS),
            "author_id": str(uuid.uuid4()),
            "mention_text": random.choice(comment_templates).format(title=title),
            "likes_count": random.randint(0, 500),
            "shares_count": random.randint(0, 100),
            "publication_timestamp": fake.date_time_between(start_date=start_date, end_date=end_date).isoformat()
        })
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
    contents_df, content_durations, content_titles = generate_contents(NUM_CONTENTS)
    users_df, user_ids = generate_users(NUM_USERS)

    # 2. Générer les données "enfant" en utilisant les IDs et titres des parents
    #    Ceci garantit la cohérence et l'intégrité référentielle !
    viewing_logs = generate_viewing_logs(NUM_VIEWING_LOGS, user_ids, content_durations)
    social_mentions = generate_social_media_mentions(NUM_SOCIAL_MENTIONS, content_titles)

    # 3. Sauvegarder tous les fichiers
    print("\n--- Sauvegarde des fichiers ---")
    save_to_csv(contents_df, os.path.join(OUTPUT_DIR, "contents.csv"))
    save_to_csv(users_df, os.path.join(OUTPUT_DIR, "users.csv"))
    save_to_json_lines(viewing_logs, os.path.join(OUTPUT_DIR, "viewing_logs.json"))
    save_to_json_lines(social_mentions, os.path.join(OUTPUT_DIR, "social_media_mentions.json"))
    
    print("\n✅ Génération des données terminée avec succès !")


if __name__ == "__main__":
    main()