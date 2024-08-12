#!/bin/bash

# Function to patch the setup script to avoid "Too many arguments" error
patch_setup_script() {
    echo "Patching setup_centralsecretservice.sh to remove unnecessary arguments..."
    
    # Locate the line with the problematic arguments
    sed -i '' 's/--template=default --branch=main//g' setup_centralsecretservice.sh
    
    echo "Patch applied successfully."
}

# Call the function to apply the patch
patch_setup_script

