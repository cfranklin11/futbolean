"""Base module for fetching data from afl_data service"""

from typing import Dict, Any, List
import time

import requests


LOCAL_AFL_DATA_SERVICE = "http://futbol_data:8080"


class DataRequestError(Exception):
    """Raised when data source returns an unsuccessful response"""


def _handle_response_data(response: requests.Response) -> List[Dict[str, Any]]:
    parsed_response = response.json()

    error = parsed_response.get("error")

    if error is not None and any(error):
        raise DataRequestError(error)

    data = parsed_response.get("data")

    if any(data):
        return data

    return []


def _make_request(
    url: str, params: Dict[str, Any] = {}, headers: Dict[str, str] = {}, retry=True
) -> requests.Response:
    response = requests.get(url, params=params, headers=headers)

    if response.status_code != 200:
        # If it's the first call to the data service in awhile, the response takes
        # longer due to the container getting started, and it sometimes times out,
        # so we'll retry once just in case
        if retry:
            time.sleep(10)
            _make_request(url, params=params, headers=headers, retry=False)

        raise RuntimeError(
            "Bad response from application: "
            f"{response.status_code} / {response.headers} / {response.text}"
        )

    return response


def fetch_data(path: str, params: Dict[str, Any] = {}) -> List[Dict[str, Any]]:
    """
    Fetch data from the afl_data service

    Args:
        path (string): API endpoint to call.
        params (dict): Query parameters to include in the API request.

    Returns:
        list of dicts, representing the AFL data requested.
    """

    service_host = LOCAL_AFL_DATA_SERVICE
    headers: Dict[str, str] = {}

    service_url = service_host + path
    response = _make_request(service_url, params=params, headers=headers)

    return _handle_response_data(response)
