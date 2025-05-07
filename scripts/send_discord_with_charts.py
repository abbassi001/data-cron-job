#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import json
import requests
from datetime import datetime
from glob import glob

def read_report_content(report_path):
    """
    Lit le contenu d'un rapport HTML et extrait les éléments clés
    """
    try:
        with open(report_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # Extraire les informations pertinentes
        # Ceci est une version simplifiée - vous pourriez avoir besoin d'un parsing HTML plus avancé
        summary = []
        
        # Extraire le nombre de fichiers traités
        if 'Nombre de fichiers traités:' in content:
            start = content.find('Nombre de fichiers traités:')
            end = content.find('</p>', start)
            if start > 0 and end > start:
                file_count = content[start:end].split(':')[1].strip()
                summary.append(f"Fichiers traités: {file_count}")
        
        # Extraire les graphiques générés
        if '<h2>Graphiques générés</h2>' in content:
            start = content.find('<h2>Graphiques générés</h2>')
            list_start = content.find('<ul>', start)
            list_end = content.find('</ul>', list_start)
            
            if list_start > 0 and list_end > list_start:
                graphs_list = content[list_start:list_end]
                graphs = []
                
                start_idx = 0
                while True:
                    li_start = graphs_list.find('<li>', start_idx)
                    if li_start == -1:
                        break
                    li_end = graphs_list.find('</li>', li_start)
                    if li_end == -1:
                        break
                    
                    graph_name = graphs_list[li_start+4:li_end].strip()
                    graphs.append(graph_name)
                    start_idx = li_end
                
                if graphs:
                    summary.append(f"Graphiques: {', '.join(graphs)}")
        
        # Si on n'a pas pu extraire d'infos, retourner un message par défaut
        if not summary:
            return "Rapport HTML généré. Consultez le fichier pour plus de détails."
        
        return "\n".join(summary)
        
    except Exception as e:
        print(f"⚠️ Erreur lors de la lecture du rapport: {str(e)}")
        return "Rapport HTML généré, mais impossible d'extraire le contenu."

def find_charts(report_dir, date_str):
    """
    Recherche les graphiques générés dans le répertoire des rapports
    """
    # Recherche les fichiers PNG qui contiennent "chart" dans le nom
    charts = glob(os.path.join(report_dir, "*_chart.png"))
    
    # Filtrer par date si nécessaire
    if date_str:
        today_charts = [c for c in charts if os.path.getmtime(c) > (datetime.now() - datetime.timedelta(days=1)).timestamp()]
        if today_charts:
            return today_charts
    
    return charts

def upload_image_to_discord(webhook_url, image_path):
    """
    Télécharge une image sur Discord en utilisant le webhook
    """
    try:
        print(f"📤 Tentative d'envoi de l'image {image_path} vers Discord...")
        
        with open(image_path, 'rb') as img:
            # Utiliser la partie file pour envoyer l'image
            files = {'file': (os.path.basename(image_path), img, 'image/png')}
            
            response = requests.post(webhook_url, files=files)
            
        if response.status_code == 200:
            print(f"✅ Image {os.path.basename(image_path)} envoyée avec succès!")
            image_url = response.json().get('attachments', [{}])[0].get('url', '')
            return image_url
        else:
            print(f"❌ Échec de l'envoi de l'image: {response.status_code}")
            print(response.text)
            return None
    
    except Exception as e:
        print(f"❌ Exception lors de l'envoi de l'image: {str(e)}")
        return None

def send_discord_message(webhook_url, message, title=None, report_path=None, chart_path=None):
    """
    Envoie un message à Discord via un webhook, avec un résumé du rapport si disponible
    
    Args:
        webhook_url (str): URL du webhook Discord
        message (str): Le message à envoyer
        title (str, optional): Titre du message (embeds)
        report_path (str, optional): Chemin vers le rapport HTML
        chart_path (str, optional): Chemin vers un graphique à inclure
    """
    # Tenter d'abord d'envoyer l'image si spécifiée
    image_url = None
    if chart_path and os.path.exists(chart_path):
        try:
            image_url = upload_image_to_discord(webhook_url, chart_path)
        except Exception as e:
            print(f"⚠️ Impossible d'envoyer l'image: {str(e)}")
    
    # Préparer le payload de base
    payload = {
        "content": message,
        "embeds": []
    }
    
    # Ajouter un embed avec titre et rapport si spécifié
    if title:
        embed = {
            "title": title,
            "description": message,
            "color": 3447003,  # Bleu Discord
            "timestamp": datetime.now().isoformat(),
            "fields": []
        }
        
        # Si un rapport est spécifié et existe
        if report_path and os.path.exists(report_path):
            report_content = read_report_content(report_path)
            
            embed["fields"].append({
                "name": "Résumé du rapport",
                "value": report_content
            })
            
            # Ajouter le chemin du rapport pour référence
            embed["footer"] = {
                "text": f"Rapport complet: {os.path.basename(report_path)}"
            }
        
        # Si on a une URL d'image, l'ajouter à l'embed
        if image_url:
            embed["image"] = {
                "url": image_url
            }
        
        payload["embeds"].append(embed)
    
    # Envoyer la requête
    try:
        response = requests.post(
            webhook_url,
            data=json.dumps(payload),
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code == 204:
            print(f"✅ Message Discord envoyé avec succès!")
            return True
        else:
            print(f"❌ Erreur lors de l'envoi du message Discord: {response.status_code}")
            print(response.text)
            return False
    
    except Exception as e:
        print(f"❌ Exception lors de l'envoi du message Discord: {str(e)}")
        return False

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 send_discord_with_charts.py webhook_url message [title] [report_path] [chart_path]")
        sys.exit(1)
    
    webhook_url = sys.argv[1]
    message = sys.argv[2]
    title = sys.argv[3] if len(sys.argv) > 3 else None
    report_path = sys.argv[4] if len(sys.argv) > 4 else None
    chart_path = sys.argv[5] if len(sys.argv) > 5 else None
    
    # Si aucun graphique n'est spécifié mais qu'on a un répertoire de rapport,
    # chercher automatiquement le premier graphique disponible
    if not chart_path and report_path:
        report_dir = os.path.dirname(report_path)
        date_str = datetime.now().strftime("%Y-%m-%d")
        charts = find_charts(report_dir, date_str)
        if charts:
            chart_path = charts[0]
            print(f"🔍 Graphique trouvé automatiquement: {chart_path}")
    
    success = send_discord_message(webhook_url, message, title, report_path, chart_path)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()