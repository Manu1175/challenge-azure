# tests/test_integration_sql.py

import pyodbc
import os
import pytest

@pytest.mark.integration
def test_sql_connection():
    conn_str = os.getenv("SqlConnectionString")
    assert conn_str is not None, "❌ Variable SqlConnectionString manquante."

    try:
        with pyodbc.connect(conn_str, timeout=5) as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT TOP 1 * FROM LiveboardData")
            result = cursor.fetchone()
            assert result is not None or result is None  # Just validate access
    except Exception as e:
        pytest.fail(f"❌ Connexion SQL échouée : {e}")