# pylint: disable=missing-docstring

import os
from unittest import TestCase
from unittest.mock import patch, mock_open
import json

from futbolean.data_import.epl_player_data import (
    save_player_urls,
    save_player_match_data,
)
from futbolean.settings import BASE_DIR, RAW_DATA_DIR


START_SEASON = "2014-2015"
END_SEASON = "2018-2019"
EPL_PLAYER_DATA_MODULE_PATH = "futbolean.data_import.epl_player_data"
EPL_PLAYER_DATA_PATH = os.path.join(BASE_DIR, "src/tests/fixtures/")


class TestEplPlayerData(TestCase):
    def setUp(self):
        self.url_filepath = os.path.join(
            EPL_PLAYER_DATA_PATH, "epl-player-urls-2014-2015-to-2018-2019.json"
        )
        self.fake_player_urls = json.load(open(self.url_filepath, "r"))

        player_data_filepath = os.path.join(
            EPL_PLAYER_DATA_PATH, "epl-player-match-data-2014-2015-to-2018-2019.json"
        )
        self.fake_player_match_data = json.load(open(player_data_filepath, "r"))

    @patch(f"{EPL_PLAYER_DATA_MODULE_PATH}.fetch_player_urls")
    @patch("builtins.open", mock_open())
    @patch("json.dump")
    def test_save_player_urls(self, _mock_json_dump, mock_fetch_data):
        mock_fetch_data.return_value = {
            "data": self.fake_player_urls,
            "skipped_urls": "",
        }

        save_player_urls(start_season=START_SEASON, end_season=END_SEASON, verbose=0)

        mock_fetch_data.assert_called_with(START_SEASON, END_SEASON, verbose=0)

        data_filepath = os.path.join(
            RAW_DATA_DIR, f"epl-player-urls-{START_SEASON}-to-{END_SEASON}.json"
        )
        open.assert_called_with(data_filepath, "w")
        dump_args, _dump_kwargs = json.dump.call_args
        self.assertIn(self.fake_player_urls, dump_args)

    @patch(f"{EPL_PLAYER_DATA_MODULE_PATH}.fetch_player_match_data")
    @patch("builtins.open", mock_open())
    @patch("json.load")
    @patch("json.dump")
    def test_save_player_match_data(
        self, _mock_json_dump, mock_json_load, mock_fetch_data
    ):
        # Just need to mock loading of URLs, and existing player data
        # (which doesn't matter here). The skipped URLs won't get loaded,
        # because there's no file to load.
        mock_json_load.side_effect = [self.fake_player_urls, []]
        mock_fetch_data.return_value = (
            {"data": self.fake_player_match_data, "skipped_urls": ""},
            None,
        )

        skipped_url_filepath = os.path.join(
            EPL_PLAYER_DATA_PATH, "skipped-epl-player-urls.json"
        )
        save_player_match_data(
            player_url_filepath=self.url_filepath,
            skipped_url_filepath=skipped_url_filepath,
            verbose=0,
        )

        mock_fetch_data.assert_called_with(self.fake_player_urls, verbose=0)

        data_filepath = os.path.join(
            RAW_DATA_DIR, f"epl-player-match-data-{START_SEASON}-to-{END_SEASON}.json"
        )
        open.assert_called_with(data_filepath, "w", encoding="utf8")
        dump_args, _dump_kwargs = json.dump.call_args
        self.assertIn(self.fake_player_match_data, dump_args)
