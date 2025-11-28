import json
import sys

try:
    with open('dbt/target/manifest.json', 'r') as f:
        data = json.load(f)
        
    nodes = data.get('nodes', {})
    print(f"Nombre de noeuds trouvés: {len(nodes)}")
    
    models = [k for k, v in nodes.items() if v.get('resource_type') == 'model']
    print(f"Nombre de modèles: {len(models)}")
    
    tests = [k for k, v in nodes.items() if v.get('resource_type') == 'test']
    print(f"Nombre de tests: {len(tests)}")
    
    # Vérifier quelques noms de modèles
    print("Exemples de modèles:", models[:5])
    
    # Vérifier s'il y a des tests de relation
    relationship_tests = [k for k, v in nodes.items() if v.get('resource_type') == 'test' and 'relationship' in k]
    print(f"Tests de relation potentiels: {len(relationship_tests)}")

except Exception as e:
    print(f"Erreur: {e}")

