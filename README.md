# futbolean

## Setup

### Data sets

- European Soccer Database:
  1. Get a [Kaggle API token](https://www.kaggle.com/docs/api) and save the `.kaggle` folder in the project root.
  2. Download the Kaggle data set: `docker-compose run --rm data_science kaggle datasets download -p ./data/01_raw/ --unzip hugomathien/soccer`
  3. Add the following to `./conf/base/credentials.yml`:
     ```
     european_soccer_credentials:
       con: sqlite+pysqlite:////app/data/01_raw/database.sqlite
     ```
- EPL per-Match Player Data (includes non-EPL matches for EPL players):
  1. Run `futbolean.data_import.epl_player_data.save_player_urls` to save a JSON list of URLs for player pages (defaults to all players who played in all seasons for which per-match data is available).
  2. Run `futbolean.data_import.epl_player_data.save_player_match_data` to save a JSON of per-match player data and a list of any URLs that were skipped due to specious `404` or `50x` responses from the server.
  3. Continue to run `save_player_match_data` with the argument `skipped_only=True` to retry the skipped URLs and complete the data set (this seems to take roughly 3 runs in totoal to get all data).
