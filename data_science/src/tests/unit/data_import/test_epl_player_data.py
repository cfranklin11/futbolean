# pylint: disable=missing-docstring

import os
from unittest import TestCase
from unittest.mock import patch, mock_open
import json

from futbolean.settings import RAW_DATA_DIR
from futbolean.data_import.epl_player_data import save_player_match_data


START_SEASON = "2014-2015"
END_SEASON = "2017-2018"
EPL_PLAYER_DATA_MODULE_PATH = "machine_learning.data_import.epl_player_data"
EPL_PLAYER_DATA_PATH = os.path.join(
    RAW_DATA_DIR, f"epl-player-match-data_{START_SEASON}_{END_SEASON}.json"
)


class TestEplPlayerData(TestCase):
    # def setUp(self):
    #     self.fake_betting_data = fake_footywire_betting_data(
    #         N_MATCHES_PER_YEAR, (START_SEASON, END_SEASON)
    #     ).to_dict("records")

    @patch(f"{EPL_PLAYER_DATA_MODULE_PATH}.fetch_player_match_data")
    @patch("builtins.open", mock_open())
    @patch("json.dump")
    def test_save_betting_data(self, _mock_json_dump, mock_fetch_data):
        mock_fetch_data.return_value = self.fake_betting_data

        save_betting_data(start_season=START_SEASON, end_season=END_SEASON, verbose=0)

        mock_fetch_data.assert_called_with(
            start_season=START_SEASON, end_season=END_SEASON, verbose=0
        )
        open.assert_called_with(EPL_PLAYER_DATA_PATH, "w")
        dump_args, _dump_kwargs = json.dump.call_args
        self.assertIn(self.fake_betting_data, dump_args)
