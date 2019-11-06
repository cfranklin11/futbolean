"""Module for calculating Fantasy Premier League scores"""

import pandas as pd
import numpy as np


def _calculate_red_cards(data_frame: pd.DataFrame) -> np.ndarray:
    """Each red card = -3"""

    return data_frame.eval("red_cards * -3").to_numpy()


def _calculate_yellow_cards(data_frame: pd.DataFrame) -> np.ndarray:
    """
    Each yellow card = -1
    Note: Red card deductions include any points deducted for yellow cards.
    """

    # Max number of redcards possible per player, per match is 1, so if a player
    # receives a red card, that nullifies any yellow card penalties, but if they didn't
    # receive a red card, the -1 multiplier for yellow cards applies.
    return data_frame.eval("yellow_cards * (red_cards - 1)").to_numpy()


def _calculate_penalty_kick_misses(data_frame: pd.DataFrame) -> np.ndarray:
    """Each penalty miss = -2"""

    return data_frame.eval("penalty_kicks_attempted - penalty_kicks_made * -2")


def _calculate_saves(data_frame: pd.DataFrame) -> np.ndarray:
    """
    Every 3 shot saves by a goalkeeper = 1
    Note: Assuming that we should drop any remainder/partial progress
        instead of rounding.
    """

    return data_frame.eval("goalkeeping_saves / 3").to_numpy().astype(int)


def _calculate_goal_assists(data_frame: pd.DataFrame) -> np.ndarray:
    """
    Each goal assist = 3
    Note: The FPL rules for assists are very specific, but we're just using the assists
        stat in the data set, which likely follows slightly different rules.
    """

    return data_frame.eval("goal_assists * 3").to_numpy()


def _calculate_played_60_mins_or_more(data_frame: pd.DataFrame) -> np.ndarray:
    """
    Playing 60 minutes or more (excluding stoppage time) = 2
    Note: I don't know whether the minutes_played data includes stoppage time
    """

    return data_frame.eval("minutes_played >= 60").astype(int).to_numpy() * 2


def _calculate_played_up_to_60_mins(data_frame: pd.DataFrame) -> np.ndarray:
    """Playing up to 60 minutes = 1"""

    return (
        data_frame.eval("minutes_played > 0 & minutes_played < 60")
        .astype(int)
        .to_numpy()
    )


def _calculate_fpl_points(data_frame: pd.DataFrame) -> np.ndarray:
    return np.array(
        [
            _calculate_played_up_to_60_mins(data_frame),
            _calculate_played_60_mins_or_more(data_frame),
            _calculate_goal_assists(data_frame),
            _calculate_saves(data_frame),
            _calculate_penalty_kick_misses(data_frame),
            _calculate_yellow_cards(data_frame),
            _calculate_red_cards(data_frame),
        ]
    ).sum(axis=0)


def add_fpl_points(data_frame: pd.DataFrame) -> pd.DataFrame:
    """Add an FPL score column to the data frame with per-player, per-match totals"""

    return data_frame.assign(fpl_score=_calculate_fpl_points)
