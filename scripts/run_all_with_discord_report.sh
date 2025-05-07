#!/bin/bash

# Ajouter ces fonctions à votre script run_all.sh ou créer un nouveau script

# Configuration Discord - REMPLACEZ PAR VOTRE URL WEBHOOK RÉELLE
DISCORD_WEBHOOK="https://discord.com/api/webhooks/1369668625744662669/Vj-FfURhiuzXR7qD_kXIaw8oAl_-A41L8spsGnCdAZ2IKYSVgeXHeJ4f_YDA2at7-cC0"

# Fonction pour créer le script de notification Discord avec rapport
create_discord_report_script() {
    local DISCORD_SCRIPT="$SCRIPT_DIR/send_discord_with_report.py"
    
    cat > "$DISCORD_SCRIPT" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import json
import requests
from datetime import datetime

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

def send_discord_message(webhook_url, message, title=None, report_path=None):
    """
    Envoie un message à Discord via un webhook, avec un résumé du rapport si disponible
    
    Args:
        webhook_url (str): URL du webhook Discord
        message (str): Le message à envoyer
        title (str, optional): Titre du message (embeds)
        report_path (str, optional): Chemin vers le rapport HTML
    """
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

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 send_discord_with_report.py webhook_url message [title] [report_path]")
        sys.exit(1)
    
    webhook_url = sys.argv[1]
    message = sys.argv[2]
    title = sys.argv[3] if len(sys.argv) > 3 else None
    report_path = sys.argv[4] if len(sys.argv) > 4 else None
    
    success = send_discord_message(webhook_url, message, title, report_path)
    sys.exit(0 if success else 1)
EOF
    
    chmod +x "$DISCORD_SCRIPT"
    echo "✅ Script d'envoi Discord avec rapport créé: $DISCORD_SCRIPT" | tee -a "$LOG_FILE"
}

# Fonction pour envoyer une notification Discord avec le rapport
notify_discord_with_report() {
    local title="$1"
    local message="$2"
    local report_path="$3"
    
    echo "🎮 Tentative d'envoi de notification Discord avec rapport: $title" | tee -a "$LOG_FILE"
    
    # Vérifier si le module requests est installé
    python3 -c "import requests" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "📦 Installation du module requests pour Python..." | tee -a "$LOG_FILE"
        pip install requests || {
            echo "❌ Impossible d'installer le module requests. Les notifications Discord ne fonctionneront pas." | tee -a "$LOG_FILE"
            return 1
        }
    fi
    
    # Créer le script Discord s'il n'existe pas déjà
    if [ ! -f "$SCRIPT_DIR/send_discord_with_report.py" ]; then
        create_discord_report_script
    fi
    
    # Envoyer la notification via Discord avec le rapport
    if python3 "$SCRIPT_DIR/send_discord_with_report.py" "$DISCORD_WEBHOOK" "$message" "$title" "$report_path"; then
        echo "✅ Notification Discord avec rapport envoyée avec succès" | tee -a "$LOG_FILE"
        return 0
    else
        echo "❌ Échec de l'envoi de la notification Discord avec rapport" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Fonction de notification adaptée pour votre script principal
send_notification() {
    show_figlet "Notify"
    echo "=== ÉTAPE 5: ENVOI DE NOTIFICATION ===" | tee -a "$LOG_FILE"
    
    # Compter les fichiers
    RAW_COUNT=$(find "$RAW_DIR" -type f -name "*.$DATE.*" | wc -l)
    PROCESSED_COUNT=$(find "$PROCESSED_DIR" -type f -mtime -1 | wc -l)
    CHART_COUNT=$(find "$REPORT_DIR" -type f -name "*_chart.png" -mtime -1 | wc -l)
    REPORT_HTML=$(find "$REPORT_DIR" -name "rapport_$DATE.html")
    
    # Créer le message de notification
    NOTIFICATION="
Le traitement automatique des données du $DATE s'est terminé avec succès.

Résumé:
- $RAW_COUNT fichiers de données téléchargés
- $PROCESSED_COUNT fichiers traités générés
- $CHART_COUNT graphiques générés
"
    
    # Envoyer la notification Discord avec le rapport HTML
    NOTIFICATION_TITLE="✅ Traitement des données réussi - $DATE"
    notify_discord_with_report "$NOTIFICATION_TITLE" "$NOTIFICATION" "$REPORT_HTML"
    
    echo "🎮 Notification avec rapport envoyée" | tee -a "$LOG_FILE"
}

# Pour tester uniquement l'envoi de rapport sans exécuter tout le script
test_discord_report() {
    # Récupérer le chemin du rapport le plus récent
    LATEST_REPORT=$(find "$REPORT_DIR" -name "rapport_*.html" | sort | tail -n 1)
    
    if [ -z "$LATEST_REPORT" ]; then
        echo "❌ Aucun rapport trouvé dans $REPORT_DIR"
        return 1
    fi
    
    echo "🔍 Rapport trouvé: $LATEST_REPORT"
    
    # Envoyer un test avec ce rapport
    notify_discord_with_report "Test de notification avec rapport" "Ceci est un test d'envoi de rapport via Discord." "$LATEST_REPORT"
}

# Si ce script est exécuté directement (pas sourcé), tester l'envoi de rapport
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Configuration minimale pour le test
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    DATA_DIR="$PROJECT_DIR/data"
    REPORT_DIR="$DATA_DIR/reports"
    LOG_FILE="/tmp/discord_test.log"
    
    # Tester l'envoi
    test_discord_report
fi