"""CLI entry point for bach-cli."""

import click

from bach_cli import __version__
from bach_cli.core import install, reload, uninstall, update


@click.group()
@click.version_option(version=__version__, prog_name="bach")
def cli():
    """Bach - Modularized bash configuration for development environment."""
    pass


@cli.command(name="install")
def install_cmd():
    """Install bach configuration."""
    install()


@cli.command(name="update")
def update_cmd():
    """Upgrade bach-cli and reinstall configuration."""
    update()


@cli.command(name="reload")
def reload_cmd():
    """Show how to reload bach configuration in the current shell."""
    reload()


@cli.command(name="uninstall")
def uninstall_cmd():
    """Uninstall bach configuration."""
    uninstall()


@cli.command()
def clean():
    """Remove bach configuration (alias for uninstall)."""
    uninstall()


def main():
    cli()
