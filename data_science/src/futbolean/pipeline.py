"""Pipeline construction."""

from typing import Dict

from kedro.pipeline import Pipeline, node

from futbolean.nodes import player


def create_pipelines(**_kwargs) -> Dict[str, Pipeline]:
    """Create the project's pipeline.

    Args:
        kwargs: Ignore any additional arguments added in the future.

    Returns:
        A mapping from a pipeline name to a ``Pipeline`` object.

    """

    return {
        "__default__": Pipeline(
            [
                node(
                    lambda *x: x,
                    [
                        "european_player_attributes",
                        "european_players",
                        "european_matches",
                        "european_leagues",
                        "european_countries",
                        "european_teams",
                        "european_team_attributes",
                        "epl_player_matches",
                    ],
                    "data",
                )
            ]
        ),
        "epl_player": create_epl_player_pipeline(),
    }


def create_epl_player_pipeline() -> Pipeline:
    """Create pipeline to process per-match data for EPL players"""

    return Pipeline([node(player.clean, "epl_player_matches", "clean_epl_players")])
