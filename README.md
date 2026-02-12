import logging
import os
import azure.functions as func
import requests
import pandas as pd
import io
import json
import pyodbc
from datetime import datetime
from dotenv import load_dotenv

# OpenTelemetry imports
from azure.monitor.opentelemetry.exporter import AzureMonitorLogExporter
from opentelemetry.sdk._logs import LoggingHandler, LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry import _logs as otel_logs
from opentelemetry import trace
from opentelemetry.trace.status import Status, StatusCode

# Charger .env en local
load_dotenv()

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

# --- Setup OpenTelemetry Logging to Application Insights ---
logger_provider = LoggerProvider()
log_exporter = AzureMonitorLogExporter()
logger_provider.add_log_record_processor(BatchLogRecordProcessor(log_exporter))
otel_logs.set_logger_provider(logger_provider)
otel_handler = LoggingHandler(level=logging.INFO, logger_provider=logger_provider)
logging.getLogger().addHandler(otel_handler)

# Tracer global
tracer = trace.get_tracer(__name__)

# 🔌 API iRail
def get_liveboard(station='Brussel-Zuid'):
    url = "https://api.irail.be/liveboard/"
    params = {
        'station': station,
        'format': 'json',
    }
    response = requests.get(url, params=params)
    response.raise_for_status()
    return response.json()

# 📊 Normalisation JSON → DataFrame
def normalize_liveboard(json_data):
    departures = json_data.get('departures', {}).get('departure', [])
    df = pd.json_normalize(departures)
    return df

# 💾 Insertion dans Azure SQL avec vérification anti-doublons
def insert_into_sql(df: pd.DataFrame):
    try:
        conn_str = os.environ['SqlConnectionString']
        with pyodbc.connect(conn_str) as conn:
            cursor = conn.cursor()

            for _, row in df.iterrows():
                # Conversion du temps
                raw_time = row.get("time")
                if pd.isnull(raw_time):
                    dt = None
                else:
                    raw_time = int(raw_time)
                    dt = datetime.fromtimestamp(raw_time / 1000) if raw_time > 1e10 else datetime.fromtimestamp(raw_time)

                station = row.get("station", "")
                vehicle = row.get("vehicle", "")
                platform = row.get("platform", "")

                # ⚠️ Vérification : n’insère que si l'entrée n'existe pas
                cursor.execute(
                    """
                    IF NOT EXISTS (
                        SELECT 1 FROM LiveboardData
                        WHERE station = ? AND vehicle = ? AND departure_time = ?
                    )
                    BEGIN
                        INSERT INTO LiveboardData (station, vehicle, departure_time, platform)
                        VALUES (?, ?, ?, ?)
                    END
                    """,
                    station, vehicle, dt,  # Pour le SELECT
                    station, vehicle, dt, platform  # Pour l'INSERT
                )

            conn.commit()
        logging.info("✅ Insertion terminée sans doublons.")
        return True, "Insertion terminée sans doublons."

    except Exception as e:
        logging.error(f"❌ Erreur SQL: {e}", exc_info=True)
        return False, str(e)

# 📥 Fonction HTTP pour requêtes manuelles
@app.function_name(name="GetiRailData")
@app.route(route="GetiRailData", methods=["GET", "POST"])
def get_irail_data(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("🔄 Fonction HTTP appelée.")
    with tracer.start_as_current_span("GetiRailData handler") as span:
        try:
            # Params GET
            station = req.params.get('station')
            response_format = req.params.get('format', 'csv').lower()
            write_to_sql = req.params.get('sql', 'true').lower() == 'true'

            # Params POST
            if req.method == "POST":
                try:
                    req_body = req.get_json()
                    station = req_body.get('station', station or 'Brussel-Zuid')
                    response_format = req_body.get('format', response_format).lower()
                    write_to_sql = req_body.get('sql', str(write_to_sql)).lower() == 'true'
                except Exception as e:
                    logging.warning(f"Pas de JSON valide: {e}")
                    if not station:
                        station = 'Brussel-Zuid'

            station = station or 'Brussel-Zuid'
            logging.info(f"📝 Paramètres → Station: {station} | Format: {response_format} | SQL: {write_to_sql}")

            json_data = get_liveboard(station)
            df = normalize_liveboard(json_data)

            if df.empty:
                return func.HttpResponse("Aucun départ trouvé.", status_code=404)

            if write_to_sql:
                success, msg = insert_into_sql(df)
                if not success:
                    span.set_status(Status(StatusCode.ERROR, msg))
                    return func.HttpResponse(f"Erreur SQL : {msg}", status_code=500)

            if response_format == 'json':
                return func.HttpResponse(
                    body=json.dumps(df.to_dict(orient='records'), indent=2),
                    status_code=200,
                    mimetype="application/json"
                )

            else:
                output = io.StringIO()
                df.to_csv(output, index=False)
                csv_data = output.getvalue()
                output.close()
                return func.HttpResponse(
                    body=csv_data,
                    status_code=200,
                    mimetype="text/csv",
                    headers={
                        "Content-Disposition": f"attachment; filename=liveboard_{station.replace(' ', '_')}.csv"
                    }
                )

        except Exception as e:
            logging.error(f"❌ Exception non gérée: {e}", exc_info=True)
            span.record_exception(e)
            span.set_status(Status(StatusCode.ERROR, str(e)))
            return func.HttpResponse(f"Server error : {str(e)}", status_code=500)

# ⏰ Timer Trigger automatique toutes les 30 minutes
@app.function_name(name="FetchiRailDataTimer")
@app.schedule(schedule="0 */30 * * * *", arg_name="timer", run_on_startup=False, use_monitor=True)
def fetch_irail_data_timer(timer: func.TimerRequest) -> None:
    logging.info("⏰ Timer Trigger : collecte automatique des données iRail.")
    with tracer.start_as_current_span("FetchiRailDataTimer handler") as span:
        try:
            station = "Brussel-Zuid"
            json_data = get_liveboard(station)
            df = normalize_liveboard(json_data)

            if df.empty:
                logging.warning("⚠️ Aucun départ détecté.")
                return

            success, msg = insert_into_sql(df)
            if success:
                logging.info("✅ Données insérées avec succès par Timer.")
            else:
                logging.error(f"❌ Insertion Timer échouée : {msg}")
                span.set_status(Status(StatusCode.ERROR, msg))

        except Exception as e:
            logging.error(f"❌ Exception Timer : {e}", exc_info=True)
            span.record_exception(e)
            span.set_status(Status(StatusCode.ERROR, str(e)))
