"""kedro data set based on fetching fresh data from the data service"""

from typing import Any, List, Dict, Callable, Union
import importlib

import pandas as pd
from kedro.io.core import AbstractDataSet


MODULE_SEPARATOR = "."


class JSONRemoteDataSet(AbstractDataSet):
    """kedro data set based on fetching fresh data from the data service"""

    def __init__(self, data_source: Union[Callable, str], load_kwargs={}, **_kwargs):
        self._load_kwargs: Dict[str, Any] = load_kwargs

        if callable(data_source):
            self.data_source = data_source
        else:
            path_parts = data_source.split(MODULE_SEPARATOR)
            function_name = path_parts[-1]
            module_path = MODULE_SEPARATOR.join(path_parts[:-1])
            module = importlib.import_module(module_path)

            self.data_source = getattr(module, function_name)

    def _load(self) -> List[Dict[str, Any]]:
        return self.data_source(**self._load_kwargs)

    def _save(self, data: pd.DataFrame) -> None:
        pass

    def _describe(self):
        return self._load_kwargs
