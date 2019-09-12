"""Application entry point."""

from pathlib import Path
from typing import Iterable

from kedro.context import KedroContext
from kedro.runner import AbstractRunner
from kedro.pipeline import Pipeline

from futbolean.pipeline import create_pipeline


class ProjectContext(KedroContext):
    """Users can override the remaining methods from the parent class here, or create new ones
    (e.g. as required by plugins)

    """

    project_name = "futbolean"
    project_version = "0.15.0"

    @property
    def pipeline(self) -> Pipeline:
        return create_pipeline()


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
    context = ProjectContext(Path.cwd(), env)

    return context.run(tags, runner, node_names, from_nodes, to_nodes)


if __name__ == "__main__":
    main()
