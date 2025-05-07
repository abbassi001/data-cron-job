#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script pour réparer les rapports HTML existants et inclure les graphiques directement.
Placez ce script dans le répertoire des scripts et exécutez-le.
"""

import os
import sys
from pathlib import Path
import re
import datetime

# Configuration
BASE_DIR = Path(__file__).parent.parent
DATA_DIR = BASE_DIR / "data"
REPORT_DIR = DATA_DIR / "reports"
DATE = datetime.datetime.now().strftime("%Y-%m-%d")

def main():
    """Fonction principale."""
    print(f"=== Réparation des rapports HTML dans {REPORT_DIR} ===")
    
    # Chercher les rapports HTML existants
    reports = list(REPORT_DIR.glob("*.html"))
    if not reports:
        print("Aucun rapport HTML trouvé.")
        return 1
    
    print(f"Trouvé {len(reports)} rapports HTML à réparer.")
    
    for report_file in reports:
        print(f"Traitement de {report_file.name}...")
        
        # Lire le contenu du rapport
        with open(report_file, "r", encoding="utf-8") as f:
            content = f.read()
        
        # Vérifier si le rapport contient déjà des images intégrées
        if "<img src=" in content:
            print(f"  Le rapport {report_file.name} a déjà des images intégrées. Ignoré.")
            continue
        
        # Trouver la section des graphiques
        graph_section = re.search(r'<h2>Graphiques générés</h2>.*?<ul>(.*?)</ul>', content, re.DOTALL)
        if not graph_section:
            print(f"  Pas de section de graphiques trouvée dans {report_file.name}. Ignoré.")
            continue
        
        # Extraire les noms des fichiers de graphiques
        chart_files = []
        for line in graph_section.group(1).split('\n'):
            match = re.search(r'<li>(.*?)</li>', line)
            if match:
                chart_files.append(match.group(1).strip())
        
        # Créer une nouvelle section de graphiques avec des images intégrées
        new_section = """
        <h2>Graphiques générés</h2>
        <p>Voici les graphiques générés pendant l'analyse:</p>
        <div style="display: flex; flex-wrap: wrap; justify-content: space-around;">
        """
        
        # Ajouter également toutes les autres visualisations dans le répertoire
        all_charts = list(REPORT_DIR.glob("*.png"))
        chart_names = [chart.name for chart in all_charts]
        
        for chart_name in chart_names:
            source = chart_name.split("_")[0]
            new_section += f"""
            <div style="margin: 20px; border: 1px solid #ddd; padding: 15px; box-shadow: 0 2px 5px rgba(0,0,0,0.1);">
                <h3>{source} - {chart_name}</h3>
                <img src="{chart_name}" alt="{chart_name}" style="max-width: 100%; height: auto;" />
            </div>
            """
        
        new_section += """
        </div>
        """
        
        # Remplacer l'ancienne section par la nouvelle
        new_content = re.sub(
            r'<h2>Graphiques générés</h2>.*?</ul>',
            new_section,
            content,
            flags=re.DOTALL
        )
        
        # Ajouter des styles CSS
        new_content = re.sub(
            r'</style>',
            """
    .chart-container { display: flex; flex-wrap: wrap; justify-content: space-around; }
    .chart { margin: 20px; border: 1px solid #ddd; padding: 15px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
    img { max-width: 100%; height: auto; }
</style>""",
            new_content
        )
        
        # Écrire le contenu modifié dans un nouveau fichier
        output_file = report_file.with_name(f"{report_file.stem}_fixed{report_file.suffix}")
        with open(output_file, "w", encoding="utf-8") as f:
            f.write(new_content)
        
        print(f"  Rapport réparé enregistré dans {output_file.name}")
    
    print("=== Réparation des rapports terminée ===")
    return 0

if __name__ == "__main__":
    sys.exit(main())