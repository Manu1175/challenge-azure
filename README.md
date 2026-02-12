# 🚆 Challenge Azure — Hardcore Branch

This project is an **Azure Functions (Python)** application that retrieves live train departure data from the **iRail API**, normalizes it using **Pandas**, stores it in **Azure SQL Database**, and exposes it through an HTTP API.

It also includes **automatic scheduled data collection** and **monitoring with OpenTelemetry + Azure Application Insights**.

---

## ✨ Features

- 📡 Fetches real-time train departures from iRail
- 📊 Normalizes JSON data into structured Pandas DataFrames
- 💾 Stores data in Azure SQL with duplicate prevention
- 🌐 HTTP API for manual queries (GET/POST)
- ⏰ Timer trigger for automatic collection every 30 minutes
- 📈 Observability using OpenTelemetry & Application Insights
- 📁 CSV or JSON export

---

## 🧠 Architecture Overview

Client / Cron
↓
Azure Functions (Python)
↓
iRail Public API
↓
Pandas Processing
↓
Azure SQL Database
↓
Application Insights (Logs & Traces)


---

## 📁 Project Structure

├── .vscode/ # VSCode settings
├── scripts/ # Utility scripts
├── tests/ # Test suite
├── function_app.py # Main Azure Functions app
├── host.json # Host configuration
├── requirements.txt # Dependencies
├── .funcignore # Deployment ignore file
└── .gitignore # Git ignore rules


---

## ⚙️ Prerequisites

Make sure you have installed:

- Python 3.8+
- Azure Functions Core Tools v4
- Azure CLI
- Git
- (Optional) VSCode + Azure Functions Extension

### Install Azure Functions Core Tools

```bash
npm install -g azure-functions-core-tools@4


---

## ⚙️ Prerequisites

Make sure you have installed:

- Python 3.8+
- Azure Functions Core Tools v4
- Azure CLI
- Git
- (Optional) VSCode + Azure Functions Extension

### Install Azure Functions Core Tools

```bash
npm install -g azure-functions-core-tools@4
📦 Installation
1️⃣ Clone the Repository
git clone https://github.com/Manu1175/challenge-azure.git
cd challenge-azure
git checkout hardcore
2️⃣ Create Virtual Environment
python -m venv .venv
source .venv/bin/activate    # Linux / macOS
# or
.venv\Scripts\activate       # Windows
3️⃣ Install Dependencies
pip install -r requirements.txt
🔐 Environment Configuration

Create a .env file for local development:
SqlConnectionString=Driver={ODBC Driver 18 for SQL Server};Server=YOUR_SERVER;Database=YOUR_DB;Uid=USER;Pwd=PASSWORD;
APPLICATIONINSIGHTS_CONNECTION_STRING=YOUR_CONNECTION_STRING
⚠️ Never commit .env files to Git.

🗄️ Database Schema

The Azure SQL database must contain the following table:
CREATE TABLE LiveboardData (
    id INT IDENTITY(1,1) PRIMARY KEY,
    station NVARCHAR(255),
    vehicle NVARCHAR(255),
    departure_time DATETIME,
    platform NVARCHAR(50)
);
Duplicate entries are prevented at insertion time.

🚀 Running Locally

Start the Azure Functions host:
func start
The app will run at:
http://localhost:7071
🌐 HTTP API Usage
Endpoint
/api/GetiRailData
✅ GET Request Example
curl "http://localhost:7071/api/GetiRailData?station=Brussels-Central&format=csv&sql=true"
Parameters
Parameter	Description	Default
station	Train station name	Brussel-Zuid
format	csv or json	csv
sql	Store in database (true/false)	true
✅ POST Request Example
curl -X POST http://localhost:7071/api/GetiRailData \
-H "Content-Type: application/json" \
-d '{
  "station": "Brussels-Central",
  "format": "json",
  "sql": true
}'
📤 Responses
JSON
[
  {
    "station": "Brussels-Central",
    "vehicle": "IC1234",
    "time": 1700000000,
    "platform": "5"
  }
]
CSV

Automatically downloaded as:
liveboard_<station>.csv
⏰ Scheduled Data Collection

A timer trigger runs every 30 minutes:
0 */30 * * * *
automatically:

Fetches data for Brussel-Zuid

Normalizes it

Stores it in SQL

Logs metrics

No user interaction required.

📈 Monitoring & Observability

This project uses:

OpenTelemetry

Azure Monitor

Application Insights

Collected Data

Logs

Exceptions

Traces

Performance metrics

Make sure APPLICATIONINSIGHTS_CONNECTION_STRING is configured.

🧪 Testing

Run all tests with:

pytest


Tests are located in the tests/ directory.

☁️ Deployment to Azure
1️⃣ Login
az login

2️⃣ Create Function App (Example)
az functionapp create \
  --resource-group my-rg \
  --consumption-plan-location westeurope \
  --runtime python \
  --runtime-version 3.9 \
  --functions-version 4 \
  --name my-function-app \
  --storage-account mystorage

3️⃣ Publish
func azure functionapp publish <APP_NAME>

⭐ Future Improvements

Add authentication

Dashboard visualization

CI/CD with GitHub Actions

Data validation layer

Retry logic for API failures

Caching
