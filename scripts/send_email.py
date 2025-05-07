#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script d'envoi d'email via SMTP
"""

import sys
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

def send_email(recipient, subject, message):
    """
    Envoie un email via Gmail SMTP
    
    Pour utiliser ce script, vous devez configurer les variables d'environnement:
    - SMTP_USER: votre adresse email Gmail
    - SMTP_PASSWORD: votre mot de passe d'application Gmail
    
    Note: Pour Gmail, vous devez créer un mot de passe d'application:
    https://myaccount.google.com/apppasswords
    """
    
    # Configuration SMTP
    smtp_server = "smtp.gmail.com"
    smtp_port = 587
    
    # Récupérer les informations d'identification - À CONFIGURER
    smtp_user = "abbassiadamou55@gmail.com"  # Remplacez par votre adresse Gmail
    smtp_password = "701000Abbas@"  # Remplacez par votre mot de passe d'application
    
    # Créer le message
    msg = MIMEMultipart()
    msg['From'] = smtp_user
    msg['To'] = recipient
    msg['Subject'] = subject
    
    # Ajouter le corps du message
    msg.attach(MIMEText(message, 'plain'))
    
    try:
        # Connexion au serveur SMTP
        server = smtplib.SMTP(smtp_server, smtp_port)
        server.starttls()  # Sécuriser la connexion
        
        # Authentification
        server.login(smtp_user, smtp_password)
        
        # Envoi du message
        server.send_message(msg)
        
        # Fermeture de la connexion
        server.quit()
        
        print(f"✅ Email envoyé avec succès à {recipient}")
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors de l'envoi de l'email: {str(e)}")
        return False

if __name__ == "__main__":
    # Vérifier les arguments
    if len(sys.argv) != 4:
        print("Usage: python3 send_email.py recipient subject message_file")
        sys.exit(1)
    
    recipient = sys.argv[1]
    subject = sys.argv[2]
    
    # Lire le contenu du fichier de message
    try:
        with open(sys.argv[3], 'r') as f:
            message = f.read()
    except Exception as e:
        print(f"❌ Erreur lors de la lecture du fichier de message: {str(e)}")
        sys.exit(1)
    
    # Envoyer l'email
    success = send_email(recipient, subject, message)
    sys.exit(0 if success else 1)