"""Module for transformation nodes for player data"""

from typing import List, Dict, Any
import re

import pandas as pd
import unidecode


FIRST_CAP_REGEX = re.compile("(.)([A-Z][a-z]+)")
ALL_CAPS_REGEX = re.compile("([a-z0-9])([A-Z])")

COL_MAP = {
    "min": "minutes_played",
    "offense_ast": "goal_assists",
    "offense_pk": "penalty_kicks_made",
    "offense_p_katt": "penalty_kicks_attempted",
    "defense_card_y": "yellow_cards",
    "defense_card_r": "red_cards",
}


def _convert_to_snake_case(name):
    s1 = FIRST_CAP_REGEX.sub(r"\1_\2", name)
    return ALL_CAPS_REGEX.sub(r"\1_\2", s1).lower()


def clean(player_data: List[Dict[str, Any]]) -> pd.DataFrame:
    """Convert raw player data to a data frame and clean up a bit """

    return (
        pd.DataFrame(player_data)
        .rename(columns=_convert_to_snake_case)
        .rename(columns=COL_MAP)
        .assign(
            player_name=lambda df: df["player"],
            player=lambda df: df["player"].map(unidecode.unidecode),
        )
        .set_index(["date", "player"])
    )
