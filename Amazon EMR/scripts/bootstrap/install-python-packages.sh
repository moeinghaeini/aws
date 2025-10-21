#!/bin/bash
# Bootstrap script to install additional Python packages for EMR cluster

set -e

echo "Starting Python package installation bootstrap..."

# Update pip
pip install --upgrade pip

# Install additional Python packages
echo "Installing data science packages..."
pip install boto3 pandas numpy scikit-learn matplotlib seaborn plotly

# Install additional packages for data processing
echo "Installing data processing packages..."
pip install openpyxl xlrd pyarrow fastparquet

# Install packages for machine learning
echo "Installing ML packages..."
pip install scikit-learn xgboost lightgbm

# Install packages for web scraping (if needed)
echo "Installing web scraping packages..."
pip install requests beautifulsoup4 lxml

# Install packages for database connectivity
echo "Installing database packages..."
pip install pymongo psycopg2-binary sqlalchemy

# Install packages for time series analysis
echo "Installing time series packages..."
pip install statsmodels prophet

# Install packages for text processing
echo "Installing text processing packages..."
pip install nltk spacy textblob

# Install packages for API development
echo "Installing API packages..."
pip install flask fastapi uvicorn

# Install packages for data validation
echo "Installing data validation packages..."
pip install great-expectations pandera

# Install packages for monitoring and logging
echo "Installing monitoring packages..."
pip install structlog python-json-logger

# Verify installations
echo "Verifying package installations..."
python -c "import pandas, numpy, boto3, sklearn; print('Core packages installed successfully')"

echo "Python package installation bootstrap completed successfully!"
