"""Module for fetching betting data from afl_data service"""

from typing import List, Dict, Any, cast, Union, Optional, Tuple
import re
import os
import json
import itertools
from warnings import warn
from datetime import date

import numpy as np
from mypy_extensions import TypedDict

from futbolean.data_import.base_data import fetch_data, DataRequestError
from futbolean.settings import RAW_DATA_DIR

# FBRef doesn't seem to have per-match player data before the 2014-2015 season.
# We may want data aggregated by season, which goes back a bit futher,
# eventually, but not for now
EARLIEST_SEASON_WITH_PLAYER_MATCH_DATA = "2014-2015"
LAST_COMPLETE_SEASON = "2018-2019"
# Based on my experience with AFL player data: I could return roughly 30,000 rows
# of data in a response, and 200 EPL players, averaging (very roughly)
# 4 seasons of data each, with roughly 40 (EPL and international) matches
# per season equals 32,000 rows of data.
# The size of these batches will likely increase with each new season, so I may
# have to eventually reduce the number of players per batch.
# PLAYER_BATCH_SIZE = 200
PLAYER_BATCH_SIZE = 50


PlayerData = TypedDict(
    "PlayerData", {"data": List[Dict[str, Any]], "skipped_urls": Union[List[str], str]}
)


def fetch_player_urls(
    start_season: str = EARLIEST_SEASON_WITH_PLAYER_MATCH_DATA,
    end_season: str = LAST_COMPLETE_SEASON,
    verbose: int = 1,
) -> PlayerData:
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
        print(f"Fetching player URLs from {start_season} to {end_season}...")

    data = fetch_data(
        "/player_urls", params={"start_season": start_season, "end_season": end_season}
    )

    if verbose == 1:
        print("Player URLs received!")

    return cast(PlayerData, data["data"])


def _fetch_player_match_data_batch(
    player_urls: List[str], idx: int, verbose: int = 1
) -> PlayerData:
    if verbose == 1:
        print(f"Fetching player stats for batch {idx + 1}")

    data = fetch_data("/player_stats", params={"player_urls": player_urls})

    if verbose == 1:
        print(f"Data for batch {idx + 1} received!")

    return cast(PlayerData, data["data"])


def fetch_player_match_data(
    player_urls: List[str] = [], verbose: int = 1
) -> Tuple[PlayerData, Optional[int]]:
    """
    Get per-match player stats for EPL going back to the 2014-2015 season

    Args:
        player_urls (array-like): List of URLs to player pages on fbref.com.
        verbose (int): Whether to print info statements (1 means yes, 0 means no).

    Returns
        list of dicts of player data.
    """

    n_urls = len(player_urls)

    if n_urls > PLAYER_BATCH_SIZE:
        n_batches = round(n_urls / PLAYER_BATCH_SIZE)
        player_url_batches = np.array_split(np.array(player_urls), n_batches)
    else:
        player_url_batches = [player_urls]

    if verbose == 1:
        batch_size = len(player_url_batches[0])
        print(
            f"Fetching player-match data in {len(player_url_batches)} batches "
            f"of roughly {batch_size} players each..."
        )

    data_batches = []
    idx = 0
    error_url_idx = None

    for idx, player_url_batch in enumerate(player_url_batches):
        try:
            data_batches.append(
                _fetch_player_match_data_batch(player_url_batch, idx, verbose=verbose)
            )
        except DataRequestError as error:
            first_url_in_batch = player_url_batch[0]
            warn(
                f"Tried to fetch batch #{idx} of data, which begins with URL: "
                f"{first_url_in_batch}, but received the error below. "
                f"Returning any data already fetched prior to the error.\n\n{error}"
            )

            error_url_idx = player_urls.index(first_url_in_batch)

            # Assuming there aren't any bugs in the code (BIG assumption, I know),
            # the error is likely from getting rate-limited by the site, so best to
            # save what we have and try again later.
            break

    if verbose == 1:
        batch_text = "batch" if idx == 0 else "batches"
        print(f"Player-match data received for {idx + 1} {batch_text}!")

    player_data = list(
        itertools.chain.from_iterable(
            [data_batch["data"] for data_batch in data_batches]
        )
    )

    skipped_urls = list(
        itertools.chain.from_iterable(
            [data_batch["skipped_urls"] for data_batch in data_batches]
        )
    )

    return {"data": player_data, "skipped_urls": skipped_urls}, error_url_idx


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
    skipped_urls = data.get("skipped_urls")

    skipped_label = ""

    if skipped_urls is not None and any(skipped_urls):
        skipped_label = "-skipped"

        filepath = os.path.join(
            RAW_DATA_DIR, f"skipped-epl-player-urls-{date.today()}.json"
        )

        with open(filepath, "w") as json_file:
            json.dump(skipped_urls, json_file, indent=2)

    filepath = os.path.join(
        RAW_DATA_DIR, f"epl-player-urls_{start_season}_{end_season}{skipped_label}.json"
    )

    with open(filepath, "w") as json_file:
        json.dump(data["data"], json_file, indent=2)

    if verbose == 1:
        print("Player URLs saved")


# Season defaulst are a bit arbitrary, but in general I prefer to keep
# the static, raw data up to the end of last season, fetching more recent data
# as necessary
def save_player_match_data(
    player_url_filename: str = "epl-player-urls_2014-2015_2018-2019.json",
    starting_url: Optional[str] = None,
    skipped_only: bool = False,
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

    seasons_match = re.search(r"\d{4}-\d{4}_\d{4}-\d{4}", player_url_filename)
    seasons_label = "" if seasons_match is None else f"-{seasons_match[0]}"
    player_url_filepath = os.path.join(RAW_DATA_DIR, player_url_filename)
    skipped_url_filepath = os.path.join(RAW_DATA_DIR, "skipped-epl-player-urls.json")

    if skipped_only:
        player_urls: List[str] = []
    else:
        with open(player_url_filepath, "r") as url_file:
            player_urls = json.load(url_file)

    if os.path.isfile(skipped_url_filepath):
        with open(skipped_url_filepath, "r") as url_file:
            skipped_urls = json.load(url_file)

        player_urls.extend(skipped_urls)

    starting_index = (
        player_urls.index(starting_url) if starting_url in player_urls else 0
    )
    data, error_url_idx = fetch_player_match_data(
        player_urls[starting_index:], verbose=verbose
    )

    player_data = data["data"]
    new_skipped_urls = data["skipped_urls"]
    urls_skipped_from_error = (
        [] if error_url_idx is None else player_urls[error_url_idx:]
    )

    # We want to keep track of formerly-skipped URLs that we still haven't scraped
    # due to some error as well as add any newly-skipped URLs
    combined_skipped_urls = (set(skipped_urls) & set(urls_skipped_from_error)) | set(
        new_skipped_urls
    )

    skipped_label = ""

    if os.path.isfile(skipped_url_filepath):
        os.remove(skipped_url_filepath)

    if skipped_urls and any(skipped_urls):
        skipped_label = "-skipped"

        filepath = skipped_url_filepath

        with open(filepath, "w") as json_file:
            json.dump(combined_skipped_urls, json_file, indent=2)

    filepath = os.path.join(
        RAW_DATA_DIR, f"epl-player-match-data{seasons_label}{skipped_label}.json"
    )

    if os.path.isfile(filepath):
        with open(filepath, "r", encoding="utf8") as json_file:
            existing_player_data = json.load(json_file)
            player_data.extend(existing_player_data)

    # Result columns have a weird UTF-8 dash in the string, so coercing to ASCII
    # results in weird encoding values
    with open(filepath, "w", encoding="utf8") as json_file:
        json.dump(player_data, json_file, indent=2, ensure_ascii=False)

    if verbose == 1:
        print("Player match data saved")


if __name__ == "__main__":
    save_player_match_data()
