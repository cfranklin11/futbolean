"""Application entry point."""

from typing import Iterable, Dict

from kedro.context import KedroContext
from kedro.runner import AbstractRunner
from kedro.pipeline import Pipeline

from futbolean.pipeline import create_pipelines, create_epl_player_pipeline
from futbolean.settings import BASE_DIR


class ProjectContext(KedroContext):
    """Users can override the remaining methods from the parent class here, or create new ones
    (e.g. as required by plugins)

    """

    project_name = "Futbolean"
    project_version = "0.15.4"

    @property
    def pipeline(self):
        return create_epl_player_pipeline()

    def _get_pipelines(self) -> Dict[str, Pipeline]:  # pylint: disable=no-self-use
        return create_pipelines()


def main(
    tags: Iterable[str] = None,
    env: str = None,
    runner: AbstractRunner = None,
    node_names: Iterable[str] = None,
    from_nodes: Iterable[str] = None,
    to_nodes: Iterable[str] = None,
):
    """Application main entry point.

    Args:
        tags: An optional list of node tags which should be used to
            filter the nodes of the ``Pipeline``. If specified, only the nodes
            containing *any* of these tags will be run.
        env: An optional parameter specifying the environment in which
            the ``Pipeline`` should be run.
        runner: An optional parameter specifying the runner that you want to run
            the pipeline with.
        node_names: An optional list of node names which should be used to filter
            the nodes of the ``Pipeline``. If specified, only the nodes with these
            names will be run.
        from_nodes: An optional list of node names which should be used as a
            starting point of the new ``Pipeline``.
        to_nodes: An optional list of node names which should be used as an
            end point of the new ``Pipeline``.

    """
    context = ProjectContext(BASE_DIR, env)

    return context.run(tags, runner, node_names, from_nodes, to_nodes)


if __name__ == "__main__":
    main()
