from flask import Flask, render_template, redirect, url_for, flash # type: ignore
import os
import re
from collections import Counter, defaultdict
import tempfile

try:
    import pymongo # type: ignore
    MONGO_AVAILABLE = True
except ImportError:
    MONGO_AVAILABLE = False
    print("WARNING: MongoDB not available, using file-based storage")

try:
    import pygal # type: ignore
    PYGAL_AVAILABLE = True
except ImportError:
    PYGAL_AVAILABLE = False
    print("WARNING: pygal not available, charts will not be displayed")

app = Flask(__name__)
app.secret_key = "ssh_logs_analyzer_secret_key"

# MongoDB connection settings for Docker
MONGO_HOST = os.environ.get('MONGO_HOST', 'mongodb')
MONGO_PORT = 27017
MONGO_URI = f"mongodb://{MONGO_HOST}:{MONGO_PORT}/"

# Path to ssh_logs.log file
LOGS_PATH = "/app/logs/ssh_logs.log"
# Path to local storage file
LOCAL_STORAGE_PATH = "/app/data/storage.json"

def parse_logs():
    # Check if the log file exists
    if not os.path.exists(LOGS_PATH):
        return None, None
    
    # Read logs from file
    with open(LOGS_PATH, "r") as file:
        logs = file.read()
    
    # Parse for new connections based on the provided format
    connections = []
    pattern = r"\w+\s+\d+\s+\d+:\d+:\d+\s+(\S+).*?from\s+(\d+\.\d+\.\d+\.\d+)"
    
    for line in logs.split('\n'):
        if line.strip():  # Skip empty lines
            match = re.search(pattern, line)
            if match and len(match.groups()) >= 2:
                machine_name = match.group(1)
                ip = match.group(2)
                connections.append((machine_name, ip))
    
    return logs, connections

def get_totals_from_storage():
    if MONGO_AVAILABLE:
        try:
            client = pymongo.MongoClient(MONGO_URI)
            db = client["ssh_logs_db"]
            logs_collection = db["ssh_connections"]
            
            totals = defaultdict(int)
            for entry in logs_collection.find():
                machine_name = entry.get("machine_name")
                ip = entry.get("ip")
                count = entry.get("count", 0)
                
                if machine_name and ip:
                    totals[(machine_name, ip)] += count
            
            return totals
        except Exception as e:
            print(f"Error retrieving data from MongoDB: {e}")
            return defaultdict(int)
    else:
        # Use file-based storage if MongoDB is not available
        import json
        if os.path.exists(LOCAL_STORAGE_PATH):
            try:
                with open(LOCAL_STORAGE_PATH, 'r') as f:
                    data = json.load(f)
                totals = defaultdict(int)
                for entry in data.get('connections', []):
                    machine_name = entry.get("machine_name")
                    ip = entry.get("ip")
                    count = entry.get("count", 0)
                    
                    if machine_name and ip:
                        totals[(machine_name, ip)] += count
                return totals
            except Exception as e:
                print(f"Error retrieving data from local storage: {e}")
                return defaultdict(int)
        return defaultdict(int)

def get_previous_from_storage():
    if MONGO_AVAILABLE:
        try:
            client = pymongo.MongoClient(MONGO_URI)
            db = client["ssh_logs_db"]
            previous_collection = db["previous"]
            
            previous_data = defaultdict(int)
            for entry in previous_collection.find():
                machine_name = entry.get("machine_name")
                ip = entry.get("ip")
                count = entry.get("count", 0)
                
                if machine_name and ip:
                    previous_data[(machine_name, ip)] += count
            
            return previous_data
        except Exception as e:
            print(f"Error retrieving previous data from MongoDB: {e}")
            return defaultdict(int)
    else:
        # Use file-based storage if MongoDB is not available
        import json
        if os.path.exists(LOCAL_STORAGE_PATH):
            try:
                with open(LOCAL_STORAGE_PATH, 'r') as f:
                    data = json.load(f)
                previous_data = defaultdict(int)
                for entry in data.get('previous', []):
                    machine_name = entry.get("machine_name")
                    ip = entry.get("ip")
                    count = entry.get("count", 0)
                    
                    if machine_name and ip:
                        previous_data[(machine_name, ip)] += count
                return previous_data
            except Exception as e:
                print(f"Error retrieving previous data from local storage: {e}")
                return defaultdict(int)
        return defaultdict(int)

def update_storage(new_counts):
    if MONGO_AVAILABLE:
        try:
            client = pymongo.MongoClient(MONGO_URI)
            db = client["ssh_logs_db"]
            logs_collection = db["ssh_connections"]
            previous_collection = db["previous"]
            
            # Clear the previous collection
            previous_collection.delete_many({})
            
            # MongoDB record constants
            timestamp = "2025-05-09"
            username = "system" 
            
            # Insert new connection records
            for (machine_name, ip), count in new_counts.items():
                # Add to main connections collection
                logs_collection.insert_one({
                    "timestamp": timestamp,
                    "user": username,
                    "machine_name": machine_name,
                    "ip": ip,
                    "count": count
                })
                
                # Add to previous collection
                previous_collection.insert_one({
                    "timestamp": timestamp,
                    "user": username,
                    "machine_name": machine_name,
                    "ip": ip,
                    "count": count
                })
            
            return True
        except Exception as e:
            print(f"Error updating MongoDB: {e}")
            return False
    else:
        # Use file-based storage if MongoDB is not available
        import json
        
        # Make sure data directory exists
        os.makedirs(os.path.dirname(LOCAL_STORAGE_PATH), exist_ok=True)
        
        # Get existing data
        data = {}
        if os.path.exists(LOCAL_STORAGE_PATH):
            try:
                with open(LOCAL_STORAGE_PATH, 'r') as f:
                    data = json.load(f)
            except Exception:
                data = {'connections': [], 'previous': []}
        else:
            data = {'connections': [], 'previous': []}
        
        # Clear previous data
        data['previous'] = []
        
        # Constants
        timestamp = "2025-05-09"
        username = "system"
        
        # Insert new records
        for (machine_name, ip), count in new_counts.items():
            # Add to main connections
            connection_entry = {
                "timestamp": timestamp,
                "user": username,
                "machine_name": machine_name,
                "ip": ip,
                "count": count
            }
            data['connections'].append(connection_entry)
            
            # Add to previous
            data['previous'].append(connection_entry.copy())
        
        # Save data to file
        try:
            with open(LOCAL_STORAGE_PATH, 'w') as f:
                json.dump(data, f, indent=2)
            return True
        except Exception as e:
            print(f"Error updating local storage: {e}")
            return False

def create_bar_chart(data, title):
    if not PYGAL_AVAILABLE or not data:
        return None
    
    # Sort data by machine_name and ip
    sorted_data = sorted(data.items())
    
    # Set up a custom configuration for the chart
    config = pygal.Config()
    config.show_legend = False
    config.x_label_rotation = 45
    config.title = title
    config.height = 500
    config.style = pygal.style.LightStyle
    config.margin_bottom = 60
    config.margin_left = 50
    config.y_title = 'Count'
    config.value_formatter = lambda x: str(int(x))
    config.tooltip_fancy_mode = False
    
    # Create the chart with the config
    bar_chart = pygal.Bar(config)
    
    # Extract the data
    x_labels = []
    values = []
    
    for (machine_name, ip), count in sorted_data:
        x_labels.append(f"{machine_name}\n{ip}")
        values.append(count)
    
    # Set the x labels and add the data
    bar_chart.x_labels = x_labels
    bar_chart.add('Connections', values)
    
    # Create a temporary file to render the chart
    temp_file = tempfile.NamedTemporaryFile(suffix='.svg', delete=False)
    temp_path = temp_file.name
    temp_file.close()
    
    try:
        # Render the chart to the temporary file
        bar_chart.render_to_file(temp_path)
        
        # Read the contents of the file
        with open(temp_path, 'r', encoding='utf-8') as f:
            svg_content = f.read()
        
        return svg_content
    finally:
        # Make sure we clean up the temporary file
        if os.path.exists(temp_path):
            os.unlink(temp_path)

def create_readme():
    # Get logs and parsed connections
    logs, connections = parse_logs()
    
    if logs is None:
        return False
    
    # Count occurrences of each (machine_name, ip) combination
    new_counts = Counter(connections)
    
    # Get previous data
    previous_data = get_previous_from_storage()
    
    # Get all totals
    previous_totals = get_totals_from_storage()
    
    # Calculate total counts
    total_counts = defaultdict(int)
    for key in set(list(new_counts.keys()) + list(previous_totals.keys())):
        total_counts[key] = new_counts[key] + previous_totals[key]
    
    # Create README content
    readme_content = "##### RAW LOGS\n"
    readme_content += logs
    
    readme_content += "\n\n##### STATISTIC\n"
    
    # Add NEW section
    readme_content += "### NEW\n"
    for (machine_name, ip), count in sorted(new_counts.items()):
        readme_content += f"{machine_name} | {ip} | {count}\n"
    
    # Add PREVIOUS section
    readme_content += "\n### PREVIOUS\n"
    if previous_data:
        for (machine_name, ip), count in sorted(previous_data.items()):
            readme_content += f"{machine_name} | {ip} | {count}\n"
    else:
        readme_content += "No previous data available\n"
    
    # Add TOTAL section
    readme_content += "\n### TOTAL\n"
    for (machine_name, ip), count in sorted(total_counts.items()):
        readme_content += f"{machine_name} | {ip} | {count}\n"
    
    # Write to README.md
    with open("README.md", "w") as readme_file:
        readme_file.write(readme_content)
    
    # Update storage
    update_success = update_storage(new_counts)
    
    return update_success

# The rest of your functions (parse_readme, parse_connection_data) and routes remain the same
def parse_readme():
    if not os.path.exists("README.md"):
        return None
    
    with open("README.md", "r") as file:
        content = file.read()
    
    # Split into main sections
    parts = content.split("##### ")
    
    sections = {}
    for part in parts:
        if not part.strip():
            continue
            
        lines = part.split('\n')
        title = lines[0].strip()
        content = '\n'.join(lines[1:]).strip()
        
        if title == "STATISTIC":
            # Further split STATISTIC into subsections
            stat_sections = {}
            subsections = content.split("### ")
            
            for subsection in subsections:
                if not subsection.strip():
                    continue
                    
                sub_lines = subsection.split('\n')
                sub_title = sub_lines[0].strip()
                sub_content = '\n'.join(sub_lines[1:]).strip()
                
                stat_sections[sub_title] = sub_content
                
            sections[title] = stat_sections
        else:
            sections[title] = content
    
    return sections

def parse_connection_data(section_content):
    connection_data = {}
    
    if not section_content or section_content == "No previous data available":
        return connection_data
    
    lines = section_content.strip().split('\n')
    for line in lines:
        if '|' in line:
            parts = line.split('|')
            if len(parts) >= 3:
                machine_name = parts[0].strip()
                ip = parts[1].strip()
                try:
                    count = int(parts[2].strip())
                    connection_data[(machine_name, ip)] = count
                except ValueError:
                    continue
    
    return connection_data

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/analyze')
def analyze():
    if not os.path.exists(LOGS_PATH):
        flash("Logs already analyzed", "info")
        return redirect(url_for('index'))
    
    success = create_readme()
    
    if success:
        flash("README.md has been created successfully", "success")
        try:
            os.remove(LOGS_PATH)
            flash("ssh_logs.log has been deleted", "success")
        except Exception as e:
            flash(f"Error deleting ssh_logs.log: {e}", "error")
    else:
        flash("Error creating README.md", "error")
    
    return redirect(url_for('index'))

@app.route('/show')
def show():
    sections = parse_readme()
    
    if sections is None:
        flash("README.md not found", "error")
        return redirect(url_for('index'))
    
    charts = {}
    
    if PYGAL_AVAILABLE and 'STATISTIC' in sections:
        stat_sections = sections['STATISTIC']
        
        if 'NEW' in stat_sections:
            new_data = parse_connection_data(stat_sections['NEW'])
            if new_data:
                charts['NEW'] = create_bar_chart(new_data, 'NEW Connections')
        
        if 'PREVIOUS' in stat_sections:
            previous_data = parse_connection_data(stat_sections['PREVIOUS'])
            if previous_data:
                charts['PREVIOUS'] = create_bar_chart(previous_data, 'PREVIOUS Connections')
    
    return render_template('show.html', sections=sections, charts=charts)

if __name__ == "__main__":
    print("Starting SSH Log Analyzer...")
    
    # Ensure data directory exists
    os.makedirs("/app/data", exist_ok=True)
    
    app.run(debug=True, host='0.0.0.0', port=5000)
