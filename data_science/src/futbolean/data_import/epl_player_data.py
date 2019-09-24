"""Module for fetching betting data from afl_data service"""

from typing import List, Dict, Any
from datetime import date
import os
import json

from futbolean.data_import.base_data import fetch_data
from futbolean.settings import RAW_DATA_DIR

FIRST_YEAR_OF_BETTING_DATA = 2010
END_OF_YEAR = f"{date.today().year}-12-31"


def fetch_player_match_data(
    start_season: str, end_season: str, verbose: int = 1
) -> List[Dict[str, Any]]:
    """
    Get per-match player stats for EPL going back to the 2014-2015 season

    Args:
        start_season (str, YYYY-YYYY): First season for which to fetch player data.
            Since EPL seasons cover two calendar years, must have the format
            of two consecutive years separated by a dash (e.g. 2015-2016).
        end_season (str, YYYY-YYYY): First season for which to fetch player data.
            Since EPL seasons cover two calendar years, must have the format
            of two consecutive years separated by a dash (e.g. 2015-2016).
        verbose (int): Whether to print info statements (1 means yes, 0 means no).

    Returns
        list of dicts of player data.
    """

    if verbose == 1:
        print("Fetching player-match data...")

    data = fetch_data(
        "/player_stats", params={"start_season": start_season, "end_season": end_season}
    )

    if verbose == 1:
        print("Player-match data received!")

    return data


# Season defaulst are a bit arbitrary, but in general I prefer to keep
# the static, raw data up to the end of last season, fetching more recent data
# as necessary
def save_player_match_data(
    start_season="2014-2015", end_season="2017-2018", verbose: int = 1
) -> None:
    """
    Save player data as a *.json file.

    Args:
        start_season (str, YYYY-YYYY): First season for which to fetch player data.
            Since EPL seasons cover two calendar years, must have the format
            of two consecutive years separated by a dash (e.g. 2015-2016).
        end_season (str, YYYY-YYYY): First season for which to fetch player data.
            Since EPL seasons cover two calendar years, must have the format
            of two consecutive years separated by a dash (e.g. 2015-2016).
        verbose (int): Whether to print info statements (1 means yes, 0 means no).

    Returns:
        None
    """

    data = fetch_player_match_data(start_season, end_season, verbose=verbose)
    filepath = os.path.join(
        RAW_DATA_DIR, f"epl-player-match-data_{start_season}_{end_season}.json"
    )

    with open(filepath, "w") as json_file:
        json.dump(data, json_file, indent=2)

    if verbose == 1:
        print("Player match data saved")


if __name__ == "__main__":
    save_player_match_data()
