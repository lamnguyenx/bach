"""CLI entry point for bach-cli."""

import click

from bach_cli import __version__
from bach_cli.core import install, reload, uninstall, update, _sync_scripts


@click.group()
@click.version_option(version=__version__, prog_name="bach")
def cli():
    """Bach - Modularized bash configuration for development environment."""
    pass


@cli.result_callback()
def auto_sync_scripts(result, **kwargs):
    """Auto-sync shell scripts after every command if they are stale."""
    # Skip sync for install/uninstall to avoid conflicts
    ctx = click.get_current_context()
    if ctx.invoked_subcommand in ("install", "uninstall", "clean"):
        return
    if _sync_scripts():
        print("\n✅ Shell scripts auto-synced to latest version.")
        print("   Run 'source ~/.bashrc' to apply changes.")


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
    """Sync scripts and show how to reload bach configuration."""
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
