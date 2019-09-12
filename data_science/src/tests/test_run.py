# pylint: disable=missing-docstring,redefined-outer-name


"""
This module contains an example test.

Tests should be placed in ``src/tests``, in modules that mirror your
project's structure, and in files named test_*.py. They are simply functions
named ``test_*`` which test a unit of logic.

To run the tests, run ``kedro test``.
"""
from pathlib import Path

import pytest

from futbolean.run import ProjectContext


@pytest.fixture
def project_context():
    return ProjectContext(str(Path.cwd()))


class TestProjectContext:
    @staticmethod
    def test_project_name(project_context):
        assert project_context.project_name == "futbolean"

    @staticmethod
    def test_project_version(project_context):
        assert project_context.project_version == "0.15.0"
