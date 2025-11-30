import pandas as pd
from faker import Faker
import random
import json
import uuid
from datetime import datetime, timedelta
import os

# Initialisation de Faker pour générer des données en français
fake = Faker('fr_FR')


def generate_age() -> int:
    """
    Génère un âge selon une distribution spécifique.
    
    Returns:
        int: Un âge entre 3 et 70 ans
    """
    # Définition des tranches d'âge avec leurs poids respectifs
    age_ranges = [
        (3, 5, 0.10),        # Enfants 3-5 (10%)
        (6, 8, 0.17),        # Enfants 6-8 (17%)
        (9, 12, 0.32),       # Enfants 9-12 (32%)
        (13, 17, 0.26),      # Ados (26%)
        (18, 25, 0.07),      # Jeunes adultes (7%)
        (26, 35, 0.05),      # Adultes (5%)
        (36, 50, 0.02),      # Adultes mûrs (2%)
        (51, 70, 0.01)       # Seniors (6%)
    ]
    
    # Selection of a range according to the weights
    weights = [w for _, _, w in age_ranges]
    ranges = [(start, end) for start, end, _ in age_ranges]
    
    selected_range = random.choices(ranges, weights=weights, k=1)[0]
    
    return random.randint(selected_range[0], selected_range[1])

def generate_country() -> str:
    """
    Génère un code pays selon une distribution spécifique.

    Return : Un des pays en String d'initiales
    """

    countries_repartition = [
        ("FR", 0.42),
        ("BE", 0.22),
        ("CH", 0.14),
        ("LU", 0.08),
        ("DE", 0.06),
        ("IT", 0.04),
        ("ES", 0.02),
        ("NL", 0.01),
        ("NO", 0.01)
    ]

    # Selection of a country according to the weights
    weights = [w for _, w in countries_repartition]
    countries = [c for c, _ in countries_repartition]
    selected_country = random.choices(countries, weights=weights, k=1)[0]
    
    return selected_country




def get_valid_device_os_combinations() -> list[dict]:
    """
    Retourne des combinaisons réalistes de device_type et OS.
    Les valeurs sont en lowercase pour correspondre à la normalisation dans les modèles dbt.
    
    Returns:
        list[dict]: Liste de dictionnaires avec 'device_type' et 'os'
    """
    combinations = [
        # Télévisions connectées
        {"device_type": "télévision connectée", "os": "android tv"},
        {"device_type": "télévision connectée", "os": "tizen"},
        {"device_type": "télévision connectée", "os": "webos"},
        
        # PC
        {"device_type": "pc", "os": "windows"},
        {"device_type": "pc", "os": "macos"},
        {"device_type": "pc", "os": "linux"},
        
        # Smartphones
        {"device_type": "smartphone", "os": "ios"},
        {"device_type": "smartphone", "os": "android"},
        
        # Tablettes
        {"device_type": "tablette", "os": "ios"},
        {"device_type": "tablette", "os": "android"},
        
        # Consoles
        {"device_type": "console de jeux", "os": "playstation os"},
        {"device_type": "console de jeux", "os": "xbox os"},
    ]
    
    return combinations


def load_series_names_from_csv(csv_path: str, max_series: int = 50) -> list[str]:
    """
    Charge des noms de séries depuis un fichier CSV statique.
    
    Args:
        csv_path (str): Chemin vers le fichier CSV
        max_series (int): Nombre maximum de séries à extraire
        
    Returns:
        list[str]: Liste de noms de séries
    """
    try:
        df = pd.read_csv(csv_path)
        # Filtrer pour ne garder que les shows (séries)
        if 'type' in df.columns and 'title' in df.columns:
            series = df[df['type'] == 'SHOW']['title'].dropna().tolist()
            if len(series) > max_series:
                series = random.sample(series, max_series)
            return series
        else:
            return []
    except Exception as e:
        print(f"Impossible de charger les noms de séries depuis {csv_path}: {e}")
        return []


def group_content_by_series(content_durations: dict) -> dict[str, list[str]]:
    """
    Groupe les content_ids par série.
    
    Args:
        content_durations (dict): Dictionnaire {content_id: duration_minutes}
        
    Returns:
        dict: Dictionnaire {series_name: [list of content_ids]}
    """
    series_episodes = {}
    
    for content_id in content_durations.keys():
        # Extraire le nom de série du content_id (avant _sXXeXX)
        # Format: series_name_s01e01
        parts = content_id.split('_')
        
        # Trouver l'index du pattern sXXeXX
        series_parts = []
        for part in parts:
            # Si on trouve un pattern qui commence par 's' suivi de chiffres
            if part.startswith('s') and len(part) >= 3 and part[1:3].isdigit():
                break
            series_parts.append(part)
        
        series_name = '_'.join(series_parts)
        
        if series_name not in series_episodes:
            series_episodes[series_name] = []
        series_episodes[series_name].append(content_id)
    
    return series_episodes


def generate_binge_watching_session(
    user_id: str,
    series_name: str,
    episodes: list[str],
    content_durations: dict,
    start_date: datetime,
    end_date: datetime,
    device_os_combinations: list[dict]
) -> list[dict]:
    """
    Génère une session de binge-watching pour un utilisateur.
    
    Une session de binge-watching consiste à regarder plusieurs épisodes
    d'une même série le même jour, sur le même appareil.
    
    Args:
        user_id (str): ID de l'utilisateur
        series_name (str): Nom de la série
        episodes (list[str]): Liste des content_ids disponibles pour cette série
        content_durations (dict): Dictionnaire {content_id: duration_minutes}
        start_date (datetime): Date de début possible
        end_date (datetime): Date de fin possible
        device_os_combinations (list[dict]): Combinaisons valides de device/OS
        
    Returns:
        list[dict]: Liste de logs de visionnage pour cette session
    """
    session_logs = []
    
    # Nombre d'épisodes à regarder (entre 3 et 6, ou moins si pas assez d'épisodes)
    num_episodes = min(random.randint(3, 6), len(episodes))
    selected_episodes = random.sample(episodes, num_episodes)
    
    # Trier les épisodes pour avoir un ordre cohérent (s01e01, s01e02, etc.)
    selected_episodes.sort()
    
    # Même jour, même device pour toute la session
    session_start = fake.date_time_between(start_date=start_date, end_date=end_date)
    device_os = random.choice(device_os_combinations)
    
    current_time = session_start
    
    for content_id in selected_episodes:
        total_duration_sec = content_durations[content_id] * 60
        
        # Pour le binge-watching, on suppose que les gens regardent presque tout l'épisode
        # (entre 70% et 100% de la durée)
        completion_rate = random.uniform(0.7, 1.0)
        watch_duration_sec = int(total_duration_sec * completion_rate)
        
        end_time = current_time + timedelta(seconds=watch_duration_sec)
        
        session_logs.append({
            "session_id": str(uuid.uuid4()),
            "user_id": user_id,
            "content_id": content_id,
            "start_timestamp": current_time.isoformat(),
            "end_timestamp": end_time.isoformat(),
            "watch_duration_seconds": watch_duration_sec,
            "device_type": device_os["device_type"],
            "os": device_os["os"]
        })
        
        # Petit break entre les épisodes (2-20 minutes)
        current_time = end_time + timedelta(minutes=random.randint(2, 20))
    
    return session_logs