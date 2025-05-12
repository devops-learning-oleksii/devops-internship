from pymongo import MongoClient
from datetime import datetime
import json
import os

def test_mongodb_connection():
    try:
        # MongoDB connection settings
        MONGO_HOST = os.environ.get('MONGO_HOST', 'mongodb')
        MONGO_PORT = 27017
        MONGO_URI = f"mongodb://{MONGO_HOST}:{MONGO_PORT}/"
        
        # Connect to MongoDB
        client = MongoClient(MONGO_URI)
        db = client["ssh_logs_db"]
        hourly_collection = db["hourly_stats"]
        
        # Get all documents from hourly_stats
        stats = list(hourly_collection.find({}, {'_id': 0}))
        
        print("\n=== MongoDB Connection Test ===")
        print(f"Connection successful!")
        print(f"Found {len(stats)} records in hourly_stats collection")
        
        if stats:
            print("\n=== Sample Data ===")
            # Print first 5 records
            for i, stat in enumerate(stats[:5], 1):
                print(f"\nRecord {i}:")
                print(json.dumps(stat, indent=2))
            
            # Print summary
            print("\n=== Summary ===")
            machines = set(stat['machine_name'] for stat in stats)
            print(f"Total machines: {len(machines)}")
            print("Machines:", ", ".join(machines))
            
            # Count total connections
            total_connections = sum(stat['count'] for stat in stats)
            print(f"Total connections: {total_connections}")
        else:
            print("\nNo data found in hourly_stats collection")
        
    except Exception as e:
        print(f"\nError connecting to MongoDB: {e}")
    finally:
        if 'client' in locals():
            client.close()

if __name__ == "__main__":
    test_mongodb_connection() 