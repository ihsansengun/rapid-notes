#!/usr/bin/env python3
"""
Script to add .env file to Xcode project as a bundle resource
"""
import os

def main():
    project_dir = "/Users/WORK2/Desktop/Rapid Notes/Rapid Notes"
    env_file = os.path.join(project_dir, "Rapid Notes", ".env")
    
    print("=== Adding .env file to Xcode project ===")
    print(f"Project directory: {project_dir}")
    print(f".env file path: {env_file}")
    
    # Check if .env file exists
    if os.path.exists(env_file):
        print("✅ .env file found")
        
        # Read the content to verify
        with open(env_file, 'r') as f:
            content = f.read()
            print(f"Content preview: {content[:100]}...")
            
        print("\nTo add .env to Xcode project:")
        print("1. In Xcode, right-click on 'Rapid Notes' folder")
        print("2. Choose 'Add Files to Rapid Notes'")
        print("3. Navigate to and select the .env file")
        print("4. Make sure 'Add to target: Rapid Notes' is checked")
        print("5. Choose 'Create folder references' (not groups)")
        print("6. Click 'Add'")
        
    else:
        print("❌ .env file not found")
        print("Please create the .env file first")

if __name__ == "__main__":
    main()