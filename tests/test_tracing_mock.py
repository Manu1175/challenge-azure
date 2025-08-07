# tests/test_tracing_mock.py

import pytest
from unittest.mock import patch
from opentelemetry import trace
from opentelemetry.trace import Tracer

@pytest.mark.integration
def test_tracing_custom_event():
    with patch("opentelemetry.trace.get_tracer") as mock_get_tracer:
        mock_tracer = mock_get_tracer.return_value
        with mock_tracer.start_as_current_span("test-span") as span:
            span.set_attribute("test.key", "value")
            span.add_event("custom.test.event")

        mock_get_tracer.assert_called_once()
        mock_tracer.start_as_current_span.assert_called_with("test-span")