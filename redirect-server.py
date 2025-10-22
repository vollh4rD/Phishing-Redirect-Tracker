from flask import Flask, request, redirect
import logging
import os
from urllib.parse import urlencode
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
app.config['TRUST_PROXY'] = True  

# New: Custom log directory (configurable via env var)
LOG_DIR = os.environ.get('LOG_DIR', '/var/log/redirect-app')
os.makedirs(LOG_DIR, exist_ok=True)


logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(LOG_DIR, 'utm_logs.txt')),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


MS_FORM_URL = os.environ.get('MS_FORM_URL', 'https://forms.office.com/r/your-form-id')  # Replace with the actual form URL/ any url
ROUTE_PATH = os.environ.get('ROUTE_PATH', '/user-migration-form')

@app.route(ROUTE_PATH)
def param_handler():

    query_params = request.args
    
    utm_params = {}
    for key in query_params:
        if key.startswith('utm_') or key.startswith('utm-'):
            normalized_key = key.replace('-', '_')
            utm_params[normalized_key] = query_params[key]
    
    original_url = request.url
    logger.info(f"Redirecting from: {original_url}")
    logger.info(f"UTM Parameters: {utm_params}")
    
    # Create separate log for utm_id and timestamp only
    if 'utm_id' in utm_params:
        timestamp = datetime.now().isoformat()
        with open(os.path.join(LOG_DIR, 'utm_id_clicks.txt'), 'a') as f:
            f.write(f"{timestamp}: {utm_params['utm_id']}\n")
    
    # Append UTM params to the form URL (use original keys for passing through)
    original_utm_pairs = [(k if '-' in k else k, v) for k, v in utm_params.items()]
    if original_utm_pairs:
        query_string = urlencode(original_utm_pairs)
        redirect_url = f"{MS_FORM_URL}?{query_string}"
    else:
        redirect_url = MS_FORM_URL
    
    return redirect(redirect_url, code=302)

@app.errorhandler(404)
def not_found(error):
    return "Not Found", 404

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)  