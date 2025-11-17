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
        int: Un âge entre 13 et 70 ans
    """
    # Définition des tranches d'âge avec leurs poids respectifs
    age_ranges = [
        (13, 16, 0.01),      # Quasiment aucun avant 16 ans (1%)
        (17, 25, 0.55),      # Grande majorité entre 17 et 25 ans (55%)
        (26, 30, 0.22),      # Un peu moins entre 25 et 30 ans (22%)
        (31, 35, 0.10),      # De moins en moins de 30 à 50 ans
        (36, 40, 0.06),
        (41, 45, 0.04),
        (46, 50, 0.015),     # Presque pas au-delà de 50 ans
        (51, 60, 0.004),
        (61, 70, 0.001)      # Jusqu'à 70 max
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
        ("FR", 0.48),
        ("BE", 0.24),
        ("CH", 0.16),
        ("LU", 0.12),
        ("DE", 0.08),
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