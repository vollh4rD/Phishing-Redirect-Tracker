import csv
import os
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

# Configuration
CSV_FILE = 'user_list.csv'  # Relative: in PROJECT_DIR (/var/www/redirect-app)
LOG_DIR = os.environ.get('LOG_DIR', '/var/log/redirect-app')
os.makedirs(LOG_DIR, exist_ok=True)  
CLICKS_LOG = os.path.join(LOG_DIR, 'utm_id_clicks.txt')  
OUTPUT_LOG = os.path.join(LOG_DIR, 'user_clicks_tracked.txt')  

def load_user_data(csv_file):
    """
    Load the CSV into a dictionary mapping utm_id to (name, email).
    Assumes CSV has headers: name, email, utm_id
    """
    user_map = {}
    csv_path = os.path.join(os.getcwd(), csv_file)  
    if not os.path.exists(csv_path):
        print(f"CSV file '{csv_path}' not found. Please ensure it exists in {os.getcwd()}.")
        return user_map
    
    with open(csv_path, mode='r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        for row in reader:
            utm_id = row.get('utm_id', '').strip()
            if utm_id:
                user_map[utm_id] = (row.get('name', '').strip(), row.get('email', '').strip())
    
    print(f"Loaded {len(user_map)} users from CSV.")
    return user_map

def track_user_clicks(user_map, clicks_log, output_log):
    """
    Read the clicks log, match utm_id to users, and log/track the details.
    Each line in clicks_log is: timestamp: utm_id
    """
    if not os.path.exists(clicks_log):
        print(f"Clicks log '{clicks_log}' not found. Run the Flask app first to generate clicks.")
        return
    
    tracked_clicks = []
    with open(clicks_log, mode='r', encoding='utf-8') as file:
        for line in file:
            line = line.strip()
            if not line or ':' not in line:
                continue
            timestamp_str, utm_id = line.split(':', 1)
            utm_id = utm_id.strip()
            
            if utm_id in user_map:
                name, email = user_map[utm_id]
                tracked_clicks.append({
                    'timestamp': timestamp_str.strip(),
                    'utm_id': utm_id,
                    'name': name,
                    'email': email
                })
                print(f"Tracked click: {name} ({email}) at {timestamp_str.strip()}")
            else:
                print(f"Unknown utm_id: {utm_id} (no matching user in CSV)")
    

    with open(output_log, mode='a', encoding='utf-8') as file:
        for click in tracked_clicks:
            log_line = f"{click['timestamp']}: {click['utm_id']} - {click['name']} ({click['email']})\n"
            file.write(log_line)
    
    print(f"Tracked {len(tracked_clicks)} user clicks and appended to '{output_log}'.")

if __name__ == '__main__':
    user_map = load_user_data(CSV_FILE)
    
    if user_map:
        track_user_clicks(user_map, CLICKS_LOG, OUTPUT_LOG)
    else:
        print("No user data loaded. Exiting.")  