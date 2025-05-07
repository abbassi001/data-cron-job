#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script avancé de traitement des données ouvertes téléchargées.
Version améliorée avec meilleure gestion des gros fichiers et visualisations avancées.
"""

import os
import sys
import logging
import datetime
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
from io import StringIO

# Configuration
BASE_DIR = Path(__file__).parent.parent
DATA_DIR = BASE_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"
REPORT_DIR = DATA_DIR / "reports"
LOG_DIR = BASE_DIR / "logs"

# Configuration du logging
today = datetime.datetime.now().strftime("%Y-%m-%d")
log_file = LOG_DIR / f"process_advanced_{today}.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# Créer les répertoires nécessaires
os.makedirs(PROCESSED_DIR, exist_ok=True)
os.makedirs(REPORT_DIR, exist_ok=True)

def get_latest_files():
    """Récupère les fichiers les plus récents pour chaque source de données."""
    latest_files = {}
    
    # Rechercher les fichiers CSV du jour
    today = datetime.datetime.now().strftime("%Y-%m-%d")
    for file in RAW_DIR.glob(f"*_{today}.csv"):
        prefix = file.name.split("_")[0]
        latest_files[prefix] = file
    
    logger.info(f"Fichiers à traiter: {latest_files}")
    return latest_files

def process_csv(file_path, output_prefix):
    """Traite un fichier CSV avec des fonctionnalités avancées."""
    try:
        logger.info(f"Traitement du fichier CSV: {file_path}")
        
        # Vérifier la taille du fichier
        file_size_mb = os.path.getsize(file_path) / (1024 * 1024)
        logger.info(f"Taille du fichier: {file_size_mb:.2f} MB")
        
        # Stratégie adaptative selon la taille du fichier
        if file_size_mb > 100:
            logger.warning(f"Le fichier est très volumineux ({file_size_mb:.2f} MB), limitation à 1 million de lignes")
            # Échantillonnage pour gros fichiers
            chunk_size = 1000  # Taille de chaque chunk
            total_rows = 0
            chunks = []
            
            # Charger les données par chunks
            for chunk in pd.read_csv(file_path, chunksize=chunk_size, sep=None, engine='python'):
                chunks.append(chunk)
                total_rows += len(chunk)
                if total_rows >= 1000000:  # Limiter à 1 million de lignes
                    break
            
            df = pd.concat(chunks, ignore_index=True)
            logger.info(f"Chargement de {len(df)} lignes par échantillonnage")
        else:
            # Pour fichiers plus petits, chargement complet
            try:
                df = pd.read_csv(file_path, sep=',')
            except:
                try:
                    df = pd.read_csv(file_path, sep=';')
                except:
                    df = pd.read_csv(file_path, sep=None, engine='python')
            
            # Limitation pour fichiers moyens
            if len(df) > 10000:
                df = df.sample(n=10000, random_state=42)
                logger.info(f"Échantillonnage aléatoire de 10000 lignes")
        
        # Informations de base
        row_count = len(df)
        col_count = len(df.columns)
        logger.info(f"Dimensions: {row_count} lignes, {col_count} colonnes")
        
        # Détecter les types de colonnes
        numeric_cols = df.select_dtypes(include=['number']).columns.tolist()
        categorical_cols = df.select_dtypes(include=['object', 'category']).columns.tolist()
        date_cols = []
        
        # Tenter de convertir des colonnes en dates
        for col in categorical_cols[:]:
            try:
                df[col] = pd.to_datetime(df[col])
                categorical_cols.remove(col)
                date_cols.append(col)
                logger.info(f"Colonne convertie en date: {col}")
            except:
                pass
        
        # Statistiques avancées pour les colonnes numériques
        if numeric_cols:
            stats_file = PROCESSED_DIR / f"{output_prefix}_stats.csv"
            stats = df[numeric_cols].describe(percentiles=[0.05, 0.25, 0.5, 0.75, 0.95])
            stats.to_csv(stats_file)
            logger.info(f"Statistiques détaillées enregistrées dans {stats_file}")
            
            # Corrélations
            if len(numeric_cols) > 1:
                corr_file = PROCESSED_DIR / f"{output_prefix}_correlations.csv"
                corr = df[numeric_cols].corr()
                corr.to_csv(corr_file)
                logger.info(f"Matrice de corrélation enregistrée dans {corr_file}")
                
                # Visualisation des corrélations
                plt.figure(figsize=(12, 10))
                sns.heatmap(corr, annot=True, cmap='coolwarm', vmin=-1, vmax=1, fmt='.2f')
                plt.title(f"Matrice de corrélation - {output_prefix}")
                corr_chart_file = REPORT_DIR / f"{output_prefix}_correlation_heatmap.png"
                plt.savefig(corr_chart_file, bbox_inches='tight')
                plt.close()
                logger.info(f"Heatmap de corrélation enregistré dans {corr_chart_file}")
            
            # Visualisations plus avancées
            for col in numeric_cols[:3]:  # Limiter à 3 colonnes pour éviter trop de graphiques
                # Histogramme avec KDE
                plt.figure(figsize=(12, 6))
                sns.histplot(df[col], kde=True)
                plt.title(f"Distribution de {col}")
                hist_file = REPORT_DIR / f"{output_prefix}_{col}_histogram.png"
                plt.savefig(hist_file)
                plt.close()
                logger.info(f"Histogramme enregistré pour {col}")
                
                # Boxplot
                plt.figure(figsize=(10, 6))
                sns.boxplot(x=df[col])
                plt.title(f"Boxplot de {col}")
                box_file = REPORT_DIR / f"{output_prefix}_{col}_boxplot.png"
                plt.savefig(box_file)
                plt.close()
        
        # Pour les colonnes catégorielles
        if categorical_cols:
            for col in categorical_cols[:3]:  # Limiter à 3 colonnes
                # Compter les valeurs
                value_counts = df[col].value_counts().head(20)  # Top 20 valeurs
                
                # Barplot
                plt.figure(figsize=(12, 8))
                sns.barplot(x=value_counts.index, y=value_counts.values)
                plt.title(f"Top 20 valeurs pour {col}")
                plt.xticks(rotation=45, ha='right')
                cat_file = REPORT_DIR / f"{output_prefix}_{col}_categories.png"
                plt.savefig(cat_file, bbox_inches='tight')
                plt.close()
        
        # Pour les colonnes de date
        if date_cols:
            for col in date_cols:
                # Agréger par mois
                try:
                    df['month'] = df[col].dt.to_period('M')
                    monthly_counts = df.groupby('month').size()
                    
                    # Tracer l'évolution temporelle
                    plt.figure(figsize=(12, 6))
                    monthly_counts.plot(kind='line', marker='o')
                    plt.title(f"Évolution temporelle par mois ({col})")
                    time_file = REPORT_DIR / f"{output_prefix}_{col}_timeline.png"
                    plt.savefig(time_file)
                    plt.close()
                    logger.info(f"Graphique temporel enregistré pour {col}")
                except Exception as e:
                    logger.warning(f"Impossible de créer le graphique temporel pour {col}: {str(e)}")
        
        # Enregistrer une version nettoyée
        clean_file = PROCESSED_DIR / f"{output_prefix}_clean.csv"
        df.to_csv(clean_file, index=False)
        logger.info(f"Fichier nettoyé enregistré dans {clean_file}")
        
        return {
            "fichier": str(file_path),
            "lignes": row_count,
            "colonnes": col_count,
            "colonnes_numeriques": numeric_cols,
            "colonnes_categorielles": categorical_cols,
            "colonnes_dates": date_cols,
            "fichiers_sortie": [str(stats_file), str(clean_file)]
        }
    
    except Exception as e:
        logger.error(f"Erreur lors du traitement du fichier CSV {file_path}: {str(e)}")
        return {"erreur": str(e)}

def generate_report(results):
    """Génère un rapport amélioré en HTML."""
    try:
        # Créer un résumé en HTML avec plus d'infos
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Rapport avancé de traitement des données - {today}</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 20px; line-height: 1.6; color: #333; }}
                h1 {{ color: #2c3e50; text-align: center; margin-bottom: 30px; }}
                h2 {{ color: #3498db; margin-top: 30px; border-bottom: 1px solid #ddd; padding-bottom: 10px; }}
                h3 {{ color: #2980b9; }}
                table {{ border-collapse: collapse; width: 100%; margin: 20px 0; box-shadow: 0 2px 3px rgba(0,0,0,0.1); }}
                th, td {{ border: 1px solid #ddd; padding: 12px; text-align: left; }}
                th {{ background-color: #f2f2f2; color: #333; font-weight: bold; }}
                tr:nth-child(even) {{ background-color: #f9f9f9; }}
                tr:hover {{ background-color: #f1f1f1; }}
                .error {{ color: #e74c3c; }}
                .success {{ color: #27ae60; }}
                .chart-container {{ display: flex; flex-wrap: wrap; justify-content: space-around; margin: 20px 0; }}
                .chart {{ margin: 10px; border: 1px solid #ddd; padding: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); max-width: 45%; }}
                .chart img {{ max-width: 100%; height: auto; }}
                .summary {{ background-color: #f8f9fa; border-left: 5px solid #3498db; padding: 15px; margin: 20px 0; }}
                footer {{ text-align: center; margin-top: 50px; font-size: 0.9em; color: #7f8c8d; border-top: 1px solid #eee; padding-top: 20px; }}
            </style>
        </head>
        <body>
            <h1>Rapport avancé de traitement des données - {today}</h1>
            
            <div class="summary">
                <p><strong>Nombre de fichiers traités:</strong> {len(results)}</p>
                <p><strong>Date du traitement:</strong> {datetime.datetime.now().strftime("%Y-%m-%d à %H:%M:%S")}</p>
                <p><strong>Statut général:</strong> {'Succès' if not any('erreur' in r for r in results) else 'Attention: Certains fichiers ont des erreurs'}</p>
            </div>
            
            <h2>Résultats détaillés par fichier</h2>
            <table>
                <tr>
                    <th>Source</th>
                    <th>Lignes</th>
                    <th>Colonnes</th>
                    <th>Colonnes numériques</th>
                    <th>Colonnes catégorielles</th>
                    <th>Colonnes de dates</th>
                    <th>Statut</th>
                </tr>
        """
        
        for result in results:
            source = Path(result.get("fichier", "")).stem.split("_")[0] if "fichier" in result else "Inconnu"
            if "erreur" in result:
                html += f"""
                <tr>
                    <td>{source}</td>
                    <td>-</td>
                    <td>-</td>
                    <td>-</td>
                    <td>-</td>
                    <td>-</td>
                    <td class="error">Erreur: {result["erreur"]}</td>
                </tr>
                """
            else:
                html += f"""
                <tr>
                    <td>{source}</td>
                    <td>{result.get("lignes", "-")}</td>
                    <td>{result.get("colonnes", "-")}</td>
                    <td>{len(result.get("colonnes_numeriques", []))}</td>
                    <td>{len(result.get("colonnes_categorielles", []))}</td>
                    <td>{len(result.get("colonnes_dates", []))}</td>
                    <td class="success">Succès</td>
                </tr>
                """
        
        html += """
            </table>
            
            <h2>Visualisations générées</h2>
            <p>Voici les graphiques générés lors de l'analyse :</p>
            
            <div class="chart-container">
        """
        
        # Lister et afficher les graphiques
        charts = list(REPORT_DIR.glob(f"*_*.png"))
        for chart_file in charts:
            chart_name = chart_file.name
            source = chart_name.split("_")[0]
            chart_type = "_".join(chart_name.split("_")[1:]).replace(".png", "")
            
            html += f"""
            <div class="chart">
                <h3>{source} - {chart_type}</h3>
                <img src="{chart_file.relative_to(REPORT_DIR.parent)}" alt="{chart_type}" />
            </div>
            """
        
        html += """
            </div>
            
            <h2>Statistiques et corrélations</h2>
            <p>Les fichiers suivants contiennent des statistiques détaillées et des analyses de corrélation :</p>
            <ul>
        """
        
        # Lister les fichiers de statistiques
        stats_files = list(PROCESSED_DIR.glob(f"*_stats.csv")) + list(PROCESSED_DIR.glob(f"*_correlations.csv"))
        for stats_file in stats_files:
            html += f"<li><a href='{stats_file.relative_to(REPORT_DIR.parent)}'>{stats_file.name}</a></li>\n"
        
        html += """
            </ul>
            
            <h2>Données traitées</h2>
            <p>Les fichiers nettoyés et transformés sont disponibles ici :</p>
            <ul>
        """
        
        # Lister les fichiers nettoyés
        clean_files = list(PROCESSED_DIR.glob(f"*_clean.csv"))
        for clean_file in clean_files:
            html += f"<li><a href='{clean_file.relative_to(REPORT_DIR.parent)}'>{clean_file.name}</a></li>\n"
        
        html += """
            </ul>
            
            <footer>
                <p>Rapport généré automatiquement par le système avancé de traitement de données le """ + datetime.datetime.now().strftime("%Y-%m-%d à %H:%M:%S") + """</p>
                <p>Pour toute question ou problème, contactez l'administrateur du système.</p>
            </footer>
        </body>
        </html>
        """
        
        # Enregistrer le rapport HTML
        report_file = REPORT_DIR / f"rapport_avance_{today}.html"
        with open(report_file, "w", encoding="utf-8") as f:
            f.write(html)
        
        logger.info(f"Rapport HTML avancé généré: {report_file}")
        return report_file
    
    except Exception as e:
        logger.error(f"Erreur lors de la génération du rapport avancé: {str(e)}")
        return None

def main():
    """Fonction principale."""
    logger.info("=== Début du traitement avancé des données ===")
    
    # Récupérer les fichiers les plus récents
    latest_files = get_latest_files()
    
    if not latest_files:
        logger.warning("Aucun fichier à traiter trouvé.")
        return 1
    
    results = []
    
    # Traiter chaque fichier
    for prefix, file_path in latest_files.items():
        result = process_csv(file_path, prefix)
        results.append(result)
    
    # Générer le rapport
    report_file = generate_report(results)
    
    if report_file:
        logger.info(f"Traitement avancé terminé avec succès. Rapport: {report_file}")
    else:
        logger.error("Échec de la génération du rapport avancé")
        return 1
    
    logger.info("=== Fin du traitement avancé des données ===")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())