import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Configuration SMTP Gmail
smtp_server = "smtp.gmail.com"
smtp_port = 587
gmail_user = "abbassiadamou55@gmail.com"  # À MODIFIER
gmail_password = "701000Abbas@"  # À MODIFIER
recipient = "abbasadoumabbas02@gmail.com"

# Message
msg = MIMEMultipart()
msg['From'] = gmail_user
msg['To'] = recipient
msg['Subject'] = "Test d'envoi d'email"
message = "Ceci est un test d'envoi d'email. Si vous recevez ce message, c'est que la configuration fonctionne."
msg.attach(MIMEText(message, 'plain'))

try:
    # Connexion
    server = smtplib.SMTP(smtp_server, smtp_port)
    server.ehlo()
    server.starttls()
    server.ehlo()
    
    # Login
    server.login(gmail_user, gmail_password)
    
    # Envoi
    text = msg.as_string()
    server.sendmail(gmail_user, recipient, text)
    server.quit()
    print("✅ Email envoyé avec succès!")
except Exception as e:
    print(f"❌ Erreur: {str(e)}")
