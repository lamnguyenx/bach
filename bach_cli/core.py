"""Core installation logic for bach-cli."""

import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import importlib.resources

BACH_HOME = Path.home() / ".local" / "share" / "bach"
BASHRC = Path.home() / ".bashrc"

BACH_BLOCK_START = "# >>> bach initialize >>>"
BACH_BLOCK_END = "# <<< bach initialize <<<"


def _get_scripts_path():
    """Get the path to the bundled scripts."""
    return importlib.resources.files("bach_cli") / "bach"


def _copy_package_tree(source, dest: Path):
    """Copy a directory tree from package resources to filesystem."""
    dest.mkdir(parents=True, exist_ok=True)
    for item in source.iterdir():
        if item.is_dir():
            _copy_package_tree(item, dest / item.name)
        else:
            (dest / item.name).write_bytes(item.read_bytes())


def _remove_bach_block():
    """Remove bach block from ~/.bashrc without touching installed files."""
    if not BASHRC.exists():
        return

    with open(BASHRC, "r") as f:
        lines = f.readlines()

    # Check if bach block exists
    has_block = False
    for line in lines:
        if BACH_BLOCK_START in line:
            has_block = True
            break

    if not has_block:
        return

    # Remove the block
    new_lines = []
    in_block = False
    for line in lines:
        if BACH_BLOCK_START in line:
            in_block = True
            continue
        if BACH_BLOCK_END in line:
            in_block = False
            continue
        if not in_block:
            new_lines.append(line)

    with open(BASHRC, "w") as f:
        f.writelines(new_lines)

    print("Removed bach block from ~/.bashrc")


def _sync_scripts():
    """Sync shell scripts from package to BACH_HOME.

    Returns True if scripts were synced, False otherwise.
    """
    scripts_path = _get_scripts_path()
    bach_init_source = scripts_path / "__init__.sh"

    if not bach_init_source.exists():
        return False

    if not BACH_HOME.exists():
        return False

    # Check if any script file differs from the installed version
    needs_sync = False
    for item in scripts_path.iterdir():
        dest = BACH_HOME / item.name
        if item.is_dir():
            # Compare each file in the directory
            for src_file in item.iterdir():
                if not src_file.is_file():
                    continue
                dest_file = dest / src_file.name
                if not dest_file.exists() or src_file.read_bytes() != dest_file.read_bytes():
                    needs_sync = True
                    break
        else:
            if not dest.exists() or item.read_bytes() != dest.read_bytes():
                needs_sync = True
                break
        if needs_sync:
            break

    if not needs_sync:
        return False

    # Copy all scripts to BACH_HOME
    for item in scripts_path.iterdir():
        dest = BACH_HOME / item.name
        if item.is_dir():
            if dest.exists():
                shutil.rmtree(dest)
            _copy_package_tree(item, dest)
        else:
            (dest).write_bytes(item.read_bytes())

    return True


def install():
    """Install bach configuration to ~/.bashrc and copy scripts."""
    scripts_path = _get_scripts_path()
    bach_init_source = scripts_path / "__init__.sh"

    if not bach_init_source.exists():
        raise RuntimeError("Cannot find bach init script in package")

    # Backup ~/.bashrc
    if BASHRC.exists():
        backup_path = BASHRC.with_suffix(
            f".backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        )
        shutil.copy2(BASHRC, backup_path)
        print(f"Backed up ~/.bashrc to {backup_path}")

    # Remove existing block if present (without removing files)
    _remove_bach_block()

    # Create bach home directory
    BACH_HOME.mkdir(parents=True, exist_ok=True)

    # Copy all scripts to BACH_HOME
    for item in scripts_path.iterdir():
        dest = BACH_HOME / item.name
        if item.is_dir():
            if dest.exists():
                shutil.rmtree(dest)
            _copy_package_tree(item, dest)
        else:
            (dest).write_bytes(item.read_bytes())

    bach_init = BACH_HOME / "__init__.sh"

    # Add new block
    bach_block = f"""{BACH_BLOCK_START}
# !! Contents within this block are managed by 'bach-cli' !!
source "{bach_init}"
eval "$(_BACH_COMPLETE=bash_source bach)"
{BACH_BLOCK_END}"""

    # Strip trailing whitespace to avoid accumulating blank lines
    with open(BASHRC, "r") as f:
        content = f.read()
    content = content.rstrip()
    with open(BASHRC, "w") as f:
        f.write(content + "\n\n" + bach_block + "\n")

    print("✅ bach installed successfully! Restart your shell or run 'source ~/.bashrc' to apply changes.")

    # Check bash version for completion support
    try:
        result = subprocess.run(["bash", "--version"], capture_output=True, text=True, timeout=5)
        version_line = result.stdout.splitlines()[0]
        # Extract version number (e.g., "3.2.57" from "GNU bash, version 3.2.57")
        import re
        match = re.search(r'version\s+(\d+)\.(\d+)', version_line)
        if match:
            major = int(match.group(1))
            minor = int(match.group(2))
            if major < 4 or (major == 4 and minor < 4):
                print("")
                print("⚠️  Note: Your bash version is too old for auto-completion (requires 4.4+).")
                print("   Shell completion has been added to ~/.bashrc but won't work until you upgrade bash.")
        else:
            # Could not parse version, skip warning
            pass
    except (subprocess.TimeoutExpired, FileNotFoundError, Exception):
        pass


def update():
    """Upgrade bach-cli package and reinstall shell scripts."""
    print("Upgrading bach-cli...")

    # Try pip first
    try:
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "--upgrade", "bach-cli"],
            check=True,
            capture_output=True,
            text=True,
        )
        print("✅ Package upgraded via pip")
    except subprocess.CalledProcessError:
        # Try pipx as fallback
        try:
            subprocess.run(
                ["pipx", "upgrade", "bach-cli"],
                check=True,
                capture_output=True,
                text=True,
            )
            print("✅ Package upgraded via pipx")
        except (subprocess.CalledProcessError, FileNotFoundError):
            print("⚠️ Failed to upgrade package automatically. Try: pip install --upgrade bach-cli")
            return

    # Reinstall shell scripts
    print("Reinstalling shell scripts...")
    install()


def _fix_bashrc_path():
    """Fix bashrc path if it points to the wrong bach init location."""
    with open(BASHRC, "r") as f:
        content = f.read()

    if BACH_BLOCK_START not in content:
        return False

    correct_path = f'source "{BACH_HOME / "__init__.sh"}"'
    if correct_path in content:
        return False

    # Find and replace the old path pattern
    old_pattern = f'source "{BACH_HOME / "bach" / "__init__.sh"}"'
    if old_pattern in content:
        content = content.replace(old_pattern, correct_path)
        with open(BASHRC, "w") as f:
            f.write(content)
        return True

    return False


def reload():
    """Check if bach is installed, sync scripts, and tell the user how to reload."""
    if not BASHRC.exists():
        print("~/.bashrc not found.")
        return

    with open(BASHRC, "r") as f:
        content = f.read()

    if BACH_BLOCK_START not in content:
        print("⚠️ bach is not installed. Run 'bach install' first.")
        return

    # Fix bashrc path if it points to the wrong location
    if _fix_bashrc_path():
        print("✅ Fixed ~/.bashrc path to point to correct bach init.")

    # Sync latest shell scripts from package
    if _sync_scripts():
        print("✅ Shell scripts updated to latest version.")

    print("✅ bach is installed. To reload your configuration, run:")
    print("   source ~/.bashrc")
    print("")
    print("   Or simply restart your shell.")


def uninstall():
    """Remove bach configuration from ~/.bashrc."""
    if not BASHRC.exists():
        print("~/.bashrc not found.")
        return

    with open(BASHRC, "r") as f:
        lines = f.readlines()

    # Check if bach block exists
    has_block = False
    for line in lines:
        if BACH_BLOCK_START in line:
            has_block = True
            break

    if not has_block:
        print("bach is not installed.")
        return

    # Remove the block
    new_lines = []
    in_block = False
    for line in lines:
        if BACH_BLOCK_START in line:
            in_block = True
            continue
        if BACH_BLOCK_END in line:
            in_block = False
            continue
        if not in_block:
            new_lines.append(line)

    with open(BASHRC, "w") as f:
        f.writelines(new_lines)

    print("Removed bach block from ~/.bashrc")

    # Clean up installed files
    if BACH_HOME.exists():
        shutil.rmtree(BACH_HOME)
        print(f"Removed {BACH_HOME}")

    print("✅ bach uninstalled successfully! Restart your shell or run 'source ~/.bashrc' to apply changes.")
