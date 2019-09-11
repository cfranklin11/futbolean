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
