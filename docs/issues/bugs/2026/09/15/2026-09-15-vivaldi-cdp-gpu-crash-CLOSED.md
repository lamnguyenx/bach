# Vivaldi CDP browser crashes seconds after launch (GPU process)

**Date**: 2026-09-15
**Status**: ✅ CLOSED — fixed in `bach_cli/bach/cdp.sh`
**Component**: `bach_cli/bach/cdp.sh` (`vivaldi_cdp`, `chrome_cdp`)

## Symptom

Launching the CDP browser with `vivaldi_cdp 9022` produced a working DevTools
endpoint (`/json/version` reachable) and then the whole browser died a couple of
seconds later:

```
DevTools listening on ws://127.0.0.1:9022/devtools/browser/...
[ERROR:chromium/gpu/ipc/client/command_buffer_proxy_impl.cc:285] ContextResult::kTransientFailure: Failed to send GpuControl.CreateCommandBuffer.
[ERROR:chromium/third_party/crashpad/crashpad/snapshot/elf/elf_dynamic_array_reader.h:64] tag not found
```

No OOM (20 GB free), no crashpad minidump written. Chrome launched the same way
on the same host showed the same GPU error and died the same way.

## Root cause

The host's GPU state (NUC, X11 :0) makes Chromium's GPU process crash; on Vivaldi
that crash takes the whole browser process down with it. `_cdp_launch` did not
pass `--disable-gpu`.

## Fix

`_cdp_launch` now passes `--disable-gpu` on every launch path (Linux fg/bg,
macOS fg/bg) for both `vivaldi_cdp` and `chrome_cdp`. CDP automation doesn't need
GPU acceleration. If a debugged profile ever needs GPU, add an escape hatch
instead of removing the flag globally.

## Verification

- `vivaldi_cdp 9022` stays alive past 30s (previously died in ~2s).
- Playwright CDP suites run green through port 9022 — see the ALT cross-reference
  below.

## Related

One distinct Vivaldi quirk surfaced while debugging this, but it is **not** fixed
by `--disable-gpu`: with `--disable-gpu` set, Vivaldi still dies when Playwright
creates a page in a fresh CDP browser context (Vivaldi spawns its internal
`app`-type UI targets inside that context). Raw `Target.createTarget` works fine.
The Android Live Translator test fixture works around it by reusing the default
context/page instead of creating new ones:
`android-live-translator/docs/plans/2026/09/15/2026-09-15-super-app-test-restructure-and-vivaldi-cdp.md`.
