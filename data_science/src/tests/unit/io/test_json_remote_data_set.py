# pylint: disable=missing-docstring

from unittest import TestCase
from unittest.mock import MagicMock, patch

from futbolean.io.json_remote_data_set import JSONRemoteDataSet


class TestJSONRemoteDataSet(TestCase):
    def setUp(self):
        self.start_season = "2015-2016"
        self.end_season = "2017-2018"
        self.data_source = MagicMock()
        self.data_set = JSONRemoteDataSet(
            data_source=self.data_source,
            load_kwargs={
                "start_season": self.start_season,
                "end_season": self.end_season,
            },
        )

    def test_load(self):
        self.data_set.load()

        self.data_source.assert_called_with(
            start_season="2015-2016", end_season="2017-2018"
        )

        with self.subTest("with string path to data_source function"):
            data_source_path = (
                "futbolean.data_import.epl_player_data.fetch_player_match_data"
            )

            with patch(data_source_path):
                data_set = JSONRemoteDataSet(
                    load_kwargs={
                        "start_season": "2015-2016",
                        "end_season": "2017-2018",
                    },
                    data_source=data_source_path,
                )

                data_set.load()

                data_set.data_source.assert_called_with(
                    start_season="2015-2016", end_season="2017-2018"
                )

    def test_save(self):
        self.data_set.save({})
