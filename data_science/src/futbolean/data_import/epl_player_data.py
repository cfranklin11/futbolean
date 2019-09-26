"""Module for fetching betting data from afl_data service"""

from typing import List, Dict, Any
import re
import os
import json

from futbolean.data_import.base_data import fetch_data
from futbolean.settings import RAW_DATA_DIR

# FBRef doesn't seem to have per-match player data before the 2014-2015 season.
# We may want data aggregated by season, which goes back a bit futher,
# eventually, but not for now
EARLIEST_SEASON_WITH_PLAYER_MATCH_DATA = "2014-2015"
LAST_COMPLETE_SEASON = "2018-2019"


def fetch_player_urls(
    start_season: str = EARLIEST_SEASON_WITH_PLAYER_MATCH_DATA,
    end_season: str = LAST_COMPLETE_SEASON,
    verbose: int = 1,
) -> List[Dict[str, Any]]:
    """
    Get list of URLs for EPL player pages on fbref.com.

    Args:
        start_season (str, YYYY-YYYY): First season for which to fetch player data.
            Since EPL seasons cover two calendar years, must have the format
            of two consecutive years separated by a dash (e.g. 2015-2016).
        end_season (str, YYYY-YYYY): First season for which to fetch player data.
            Since EPL seasons cover two calendar years, must have the format
            of two consecutive years separated by a dash (e.g. 2015-2016).
        verbose (int): Whether to print info statements (1 means yes, 0 means no).

    Returns
        List of player URLs.
    """

    if verbose == 1:
        print("Fetching player URLs...")

    data = fetch_data(
        "/player_urls", params={"start_season": start_season, "end_season": end_season}
    )

    if verbose == 1:
        print("Player URLs received!")

    return data


def fetch_player_match_data(
    player_urls: List[str] = [], verbose: int = 1
) -> List[Dict[str, Any]]:
    """
    Get per-match player stats for EPL going back to the 2014-2015 season

    Args:
        player_urls (array-like): List of URLs to player pages on fbref.com.
        verbose (int): Whether to print info statements (1 means yes, 0 means no).

    Returns
        list of dicts of player data.
    """

    if verbose == 1:
        print("Fetching player-match data...")

    data = fetch_data("/player_stats", params={"player_urls": player_urls})

    if verbose == 1:
        print("Player-match data received!")

    return data


def save_player_urls(
    start_season: str = EARLIEST_SEASON_WITH_PLAYER_MATCH_DATA,
    end_season: str = LAST_COMPLETE_SEASON,
    verbose: int = 1,
) -> None:
    """
    Get list of URLs for EPL player pages on fbref.com.

    Args:
        start_season (str, YYYY-YYYY): First season for which to fetch player data.
            Since EPL seasons cover two calendar years, must have the format
            of two consecutive years separated by a dash (e.g. 2015-2016).
        end_season (str, YYYY-YYYY): First season for which to fetch player data.
            Since EPL seasons cover two calendar years, must have the format
            of two consecutive years separated by a dash (e.g. 2015-2016).
        verbose (int): Whether to print info statements (1 means yes, 0 means no).

    Returns
        None
    """

    data = fetch_player_urls(start_season, end_season, verbose=verbose)
    filepath = os.path.join(
        RAW_DATA_DIR, f"epl-player-urls_{start_season}_{end_season}.json"
    )

    with open(filepath, "w") as json_file:
        json.dump(data, json_file, indent=2)

    if verbose == 1:
        print("Player URLs saved")


# Season defaulst are a bit arbitrary, but in general I prefer to keep
# the static, raw data up to the end of last season, fetching more recent data
# as necessary
def save_player_match_data(
    player_url_filepath: str = "data/01_raw/epl-player-urls_2014-2015_2018-2019.json",
    verbose: int = 1,
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

    seasons_match = re.search(r"\d{4}-\d{4}", player_url_filepath)

    seasons_label = (seasons_match and f"_{seasons_match[0]}") or ""

    with open(player_url_filepath, "r") as url_file:
        player_urls = json.load(url_file)

    data = fetch_player_match_data(player_urls, verbose=verbose)
    filepath = os.path.join(RAW_DATA_DIR, f"epl-player-match-data{seasons_label}.json")

    with open(filepath, "w") as json_file:
        json.dump(data, json_file, indent=2)

    if verbose == 1:
        print("Player match data saved")


if __name__ == "__main__":
    save_player_match_data()
