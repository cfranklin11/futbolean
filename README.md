# futbolean

## Setup

### Data sets

- European Soccer Database:
  1. Get a [Kaggle API token](https://www.kaggle.com/docs/api) and save the `.kaggle` folder in the project root.
  2. Run `docker-compose run --rm data_science kaggle datasets download -p ./data/01_raw/ --unzip hugomathien/soccer`
  3. Extract data into useable form using `sqlite3` package (TBD).
