#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import json
import requests
from datetime import datetime

def send_discord_message(webhook_url, message, title=None, image_path=None):
    """
    Envoie un message à Discord via un webhook
    
    Args:
        webhook_url (str): URL du webhook Discord
        message (str): Le message à envoyer
        title (str, optional): Titre du message (embeds)
        image_path (str, optional): Chemin vers une image à joindre
    """
    # Préparer le payload de base
    payload = {
        "content": message,
        "embeds": []
    }
    
    # Ajouter un embed avec titre si spécifié
    if title:
        embed = {
            "title": title,
            "description": message,
            "color": 3447003,  # Bleu Discord
            "timestamp": datetime.now().isoformat()
        }
        
        # Si une image est spécifiée et existe
        if image_path and os.path.exists(image_path):
            # Pour Discord, nous ne pouvons pas joindre directement un fichier dans un webhook simple
            # Il faudrait héberger l'image quelque part et utiliser l'URL
            # On peut mentionner l'image dans le message
            embed["footer"] = {
                "text": f"Une image a été générée: {os.path.basename(image_path)}"
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
        print("Usage: python3 send_discord.py webhook_url message [title] [image_path]")
        sys.exit(1)
    
    webhook_url = sys.argv[1]
    message = sys.argv[2]
    title = sys.argv[3] if len(sys.argv) > 3 else None
    image_path = sys.argv[4] if len(sys.argv) > 4 else None
    
    success = send_discord_message(webhook_url, message, title, image_path)
    sys.exit(0 if success else 1)