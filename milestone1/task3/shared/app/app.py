from flask import Flask, render_template, jsonify, request
import os
import re
from datetime import datetime, timedelta
from pymongo import MongoClient
import pygal
from collections import defaultdict

app = Flask(__name__)

# MongoDB connection with URI from environment variable
MONGODB_URI = os.getenv('MONGODB_URI', 'mongodb://mongodb:27017/')
client = MongoClient(MONGODB_URI)
db = client['ssh_logs']
connections_collection = db['connections']
logs_collection = db['logs']

def parse_log_line(line):
    pattern = r'(\w+ \d+ \d+:\d+:\d+) (\w+) sshd\[\d+\]: Accepted publickey for \w+ from (\d+\.\d+\.\d+\.\d+)'
    match = re.match(pattern, line)
    if match:
        timestamp_str, machine_name, ip = match.groups()
        # Add current year to the timestamp since it's not in the log
        current_year = datetime.now().year
        timestamp_str = f"{timestamp_str} {current_year}"
        timestamp = datetime.strptime(timestamp_str, '%b %d %H:%M:%S %Y')
        return {
            'timestamp': timestamp,
            'machine_name': machine_name,
            'ip': ip
        }
    return None

def update_database():
    log_path = '/app/logs/ssh_logs.log'
    if not os.path.exists(log_path):
        return False
    
    with open(log_path, 'r') as f:
        for line in f:
            # Store raw log line in logs collection
            log_entry = {
                'raw_log': line.strip(),
                'timestamp': datetime.now(),
                'parsed': False
            }
            # Check if this log entry already exists
            existing_log = logs_collection.find_one({'raw_log': line.strip()})
            if not existing_log:
                logs_collection.insert_one(log_entry)
            
            # Parse and store in connections collection
            log_data = parse_log_line(line)
            if log_data:
                existing = connections_collection.find_one({
                    'timestamp': log_data['timestamp'],
                    'machine_name': log_data['machine_name'],
                    'ip': log_data['ip']
                })
                if not existing:
                    connections_collection.insert_one(log_data)
                    # Update the log entry as parsed
                    if existing_log:
                        logs_collection.update_one(
                            {'_id': existing_log['_id']},
                            {'$set': {'parsed': True}}
                        )
    # Delete the log file after processing
    os.remove(log_path)
    return True

def get_time_based_stats(start_date, end_date):
    # Check if collection is empty
    if connections_collection.count_documents({}) == 0:
        return [], []
    
    # Calculate time difference to determine appropriate interval
    time_diff = end_date - start_date
    hours_diff = time_diff.total_seconds() / 3600
    
    # Determine time format based on the range
    if hours_diff <= 24:
        # For 24 hours or less, show hourly data
        time_format = '%H:00'
        interval = timedelta(hours=1)
    elif hours_diff <= 168:  # 7 days
        # For up to a week, show daily data
        time_format = '%Y-%m-%d'
        interval = timedelta(days=1)
    else:
        # For longer periods, show weekly data
        time_format = '%Y-W%W'
        interval = timedelta(weeks=1)
    
    # Create time buckets
    current = start_date
    time_buckets = []
    while current <= end_date:
        time_buckets.append(current.strftime(time_format))
        current += interval
    
    # Get data from MongoDB
    pipeline = [
        {
            '$match': {
                'timestamp': {
                    '$gte': start_date,
                    '$lte': end_date
                }
            }
        },
        {
            '$group': {
                '_id': {
                    'time': {'$dateToString': {'format': time_format, 'date': '$timestamp'}},
                    'machine': '$machine_name'
                },
                'count': {'$sum': 1}
            }
        },
        {
            '$group': {
                '_id': '$_id.time',
                'machines': {
                    '$push': {
                        'machine': '$_id.machine',
                        'count': '$count'
                    }
                }
            }
        },
        {
            '$sort': {'_id': 1}
        }
    ]
    
    results = list(connections_collection.aggregate(pipeline))
    
    # Format data for the graph
    formatted_data = defaultdict(lambda: defaultdict(int))
    for result in results:
        time_bucket = result['_id']
        for machine_data in result['machines']:
            formatted_data[time_bucket][machine_data['machine']] = machine_data['count']
    
    return formatted_data, time_buckets

def create_graph(start_date, end_date):
    time_data, time_buckets = get_time_based_stats(start_date, end_date)
    
    # Create a smaller line chart for time series
    line_chart = pygal.Line(width=1000, height=500)
    line_chart.title = f'SSH Connections Over Time ({start_date.strftime("%Y-%m-%d %H:%M")} to {end_date.strftime("%Y-%m-%d %H:%M")})'
    line_chart.title_font_size = 10  # smaller title
    line_chart.legend_font_size = 8  # smaller legend
    line_chart.legend_box_size = 8    # smaller legend box
    line_chart.margin = 7            # less margin
    
    # Get unique machines
    all_machines = set()
    for time_bucket in time_data.values():
        all_machines.update(time_bucket.keys())
    # Add data for each machine
    for machine in sorted(all_machines):
        data = [time_data[time_bucket].get(machine, 0) for time_bucket in time_buckets]
        line_chart.add(machine, data)
    
    # Set x-axis labels
    line_chart.x_labels = time_buckets
    line_chart.x_label_rotation = 45
    
    # Add interactive features and horizontal legend
    line_chart.show_legend = True
    line_chart.legend_at_bottom = True
    line_chart.legend_horizontal = True
    line_chart.truncate_legend = -1
    line_chart.tooltip_font_size = 12
    line_chart.value_font_size = 12
    line_chart.x_label_font_size = 10
    line_chart.js_functions = ['function(x) { return x; }']
    line_chart.interactive = True
    
    # Save the chart
    chart_path = os.path.join('static', 'connections_chart.svg')
    line_chart.render_to_file(chart_path)
    return chart_path

def parse_log_time(raw_log):
    # Example: May 12 14:30:12 sftp3 ...
    match = re.match(r'([A-Za-z]{3} \d{1,2} \d{2}:\d{2}:\d{2})', raw_log)
    if match:
        log_time_str = match.group(1)
        # Add current year
        current_year = datetime.now().year
        try:
            log_time = datetime.strptime(f"{log_time_str} {current_year}", "%b %d %H:%M:%S %Y")
            return log_time
        except Exception:
            return None
    return None

@app.route('/')
def index():
    # Check if we have any data in MongoDB
    if connections_collection.count_documents({}) == 0:
        # Try to load initial data
        update_database()
    return render_template('index.html')

@app.route('/update', methods=['POST'])
def update():
    log_path = '/app/logs/ssh_logs.log'
    if not os.path.exists(log_path):
        return jsonify({'status': 'error', 'message': 'logs already analyzed'})
    success = update_database()
    if success:
        return jsonify({'status': 'success'})
    return jsonify({'status': 'error', 'message': 'Failed to update database'})

@app.route('/filter', methods=['POST'])
def filter_data():
    try:
        # Parse dates from the format "YYYY-MM-DD HH:mm"
        start_date_str = request.json.get('start_date')
        end_date_str = request.json.get('end_date')
        start_date = datetime.strptime(start_date_str, '%Y-%m-%d %H:%M')
        end_date = datetime.strptime(end_date_str, '%Y-%m-%d %H:%M')
        # Use the user's exact end time, do not force 23:59
        chart_path = create_graph(start_date, end_date)
        return jsonify({
            'status': 'success',
            'chart_path': chart_path
        })
    except ValueError as e:
        return jsonify({
            'status': 'error',
            'message': 'Invalid date format. Please use YYYY-MM-DD HH:mm format'
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        })

@app.route('/logs')
def logs():
    machine = request.args.get('machine', '')
    start_date_str = request.args.get('start_date', '')
    end_date_str = request.args.get('end_date', '')

    # Build MongoDB query for machine only (not time)
    query = {}
    if machine:
        query['raw_log'] = {'$regex': f'\\b{machine}\\b'}

    # Get all logs for this machine (or all)
    all_logs = list(logs_collection.find(query).sort('timestamp', -1))

    # Parse and filter by log time in Python
    filtered_logs = []
    start_dt = None
    end_dt = None
    if start_date_str and end_date_str:
        try:
            start_dt = datetime.strptime(start_date_str, '%Y-%m-%d %H:%M')
            end_dt = datetime.strptime(end_date_str, '%Y-%m-%d %H:%M')
        except Exception:
            pass

    for log in all_logs:
        log_time = None
        if 'raw_log' in log:
            log_time = parse_log_time(log['raw_log'])
        log['parsed_log_time'] = log_time
        # Filter by time if both start and end are set
        if start_dt and end_dt and log_time:
            if start_dt <= log_time <= end_dt:
                filtered_logs.append(log)
        elif not start_dt or not end_dt:
            filtered_logs.append(log)

    # Pagination
    page = request.args.get('page', 1, type=int)
    per_page = 50
    skip = (page - 1) * per_page
    logs = filtered_logs[skip:skip+per_page]
    total_logs = len(filtered_logs)
    total_pages = (total_logs + per_page - 1) // per_page

    # Get unique machines from all logs
    machines = set()
    for log in logs_collection.find():
        if 'raw_log' in log:
            match = re.search(r'\b(sftp[123])\b', log['raw_log'])
            if match:
                machines.add(match.group(1))

    return render_template('logs.html',
        logs=logs,
        current_page=page,
        total_pages=total_pages,
        machines=sorted(list(machines)),
        selected_machine=machine,
        start_date=start_date_str,
        end_date=end_date_str)

if __name__ == '__main__':
    # Create static directory if it doesn't exist
    os.makedirs('static', exist_ok=True)
    app.run(host='0.0.0.0', port=5000, debug=True) 

