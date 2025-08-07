# tests/test_main.py

import pytest
from function_app import main

def test_dummy():
    assert 1 + 1 == 2

def test_normalize():
    sample_data = {
        "departures": {
            "departure": [
                {
                    "station": "Brussel-Zuid",
                    "vehicle": "BE.NMBS.IC1234",
                    "time": "1698937200",
                    "platform": "5"
                }
            ]
        }
    }
    df = main.normalize_liveboard(sample_data)
    assert df.shape[0] == 1
    assert "station" in df.columns