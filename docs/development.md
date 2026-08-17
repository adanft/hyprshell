# Working on hyprshell

```sh
./run-tests.sh             # everything, on the compositor you are using
./run-tests.sh --isolated  # everything, compositor stages nested away
./run-tests.sh --js        # Node and Python only, no compositor needed
```

Node contract tests, the Python benchmark tests, QML component tests, then five
stages that need a real compositor: two notification and overlay harnesses, a
panel interaction harness, a center interaction harness, a smoke test that
instantiates every window and checks it built without warnings, and an overlay
cycle benchmark. The compositor stages say so rather than passing quietly when
there is no compositor.

Layout is vertical: each feature owns its components, sizing and tests under
`features/`, shared pieces live in `shared/`, system access in `services/`, and
the design tokens — colors, typography, spacing, icons, shape, motion — in
`theme/`.

Node and Python come from your system; `qmltestrunner` ships with
`qt6-declarative` and is located by `scripts/find-qmltestrunner.sh`, which also
honours `QMLTESTRUNNER` if you want to point it somewhere else.

## What only a running shell can answer

Three of those stages exist because the question they answer disappears the
moment you take the shell apart.

`panel-interaction-harness.qml` opens the overlays. Instantiating one, which is
what the smoke test does, only proves it compiles; `shell.qml` reaches every
overlay through `OverlayArbiter` and `OverlayLifecycleLoader`, and that path —
lazy activation, the arbiter displacing whatever was up, the panel's own
`open()` — is not the one an instantiation runs. It holds the invariant the
arbiter exists for: exactly one overlay alive at a time, and a displaced one
*destroyed*. Destroyed rather than hidden is the whole point, and it is a count
rather than anything you could see on screen.

`center-interaction-harness.qml` covers the two panels that do not open like
those five. The control center is opened by a signal that rises `BarLayout` →
`BarContent` → `BarWindow` and lands on a handler that flips a loader `BarWindow`
keeps to itself, so the harness emits that signal on the real `BarContent` and
lets the whole chain run; because the loader is private, it also holds a
`ControlCenter` of its own to assert that `open()` lands on the section it was
given. The notification center is the one loader in the shell with
`directVisibility` set — a branch of `OverlayLifecycleLoader` that nothing else
takes. It stops at the edge of the shell: sections are exercised by name and
nothing is asked of BlueZ or NetworkManager, which live on the system bus that
the isolated session does not isolate, so a test that toggled them would be
flipping a real radio on a real machine.

`scripts/shell-cycle-bench.sh` is the only stage that runs `shell.qml` itself.
It opens and closes every overlay over `qs ipc`, the way a person does, while
`scripts/hyprshell-bench.py` samples the process tree. Its verdict is deliberately
lopsided: **file descriptors fail the run, memory only reports.** A descriptor a
closed overlay never released is an integer that does not drift, while RSS moves
with the allocator underneath it, so a memory threshold tight enough to catch a
leak also fails on nothing at all.

Two things in there were measured rather than assumed, and both are written down
where they are used. The benchmark throws away a full warm-up cycle first,
because the first open of an overlay compiles its QML and spins up thread pools
— from cold that reads as +13 descriptors and +53 MB, none of it a leak. And the
descriptor tolerance is two, because an idle shell that opens nothing drifts by
one on its own. Raise `CYCLE_BENCH_CYCLES` to raise the sensitivity: a real leak
scales with the cycles and the noise floor does not.

## Why `--isolated` exists

The QML stages launch the shell for real, which means they do what the shell
does: `features/statusbar/BarWindow.qml` reserves a layer-shell exclusive zone,
and `theme/runtime/HyprTheme.qml` runs `hyprctl reload`. Aimed at the compositor
you are working on, the first relayouts every window and the second makes
Hyprland re-apply its monitors, binds and window rules — three times per run,
once for each `qs` process the script starts.

`--isolated` hands those stages a session of their own: a nested Hyprland with a
private D-Bus bus and private `XDG_*` directories, built by
`scripts/isolated-session.sh` and configured by `scripts/isolated-hyprland.conf`.
The exclusive zone is reserved there, the reload lands there, and `theme.conf`
is written there rather than in `~/.config/hypr`.

The nested compositor is one ordinary window of class `aquamarine`, so on a
tiling setup it retiles the workspace you are on while the suite runs. The
harness does not touch your compositor to fix that — a rule in your own config
applies before the window ever maps, which no amount of reaching in afterwards
can match. In the Lua config format:

```lua
hl.window_rule({
	name = "hyprshell-isolated-session",
	match = { class = "aquamarine" },
	float = true,
	no_focus = true,
	pin = true,
})
```

All three matter, and the reason is the same one each time: **this window has to
keep being drawn, or everything inside it stops.** It is an ordinary client of
your session, so your session stops sending it frame callbacks the moment it is
not on screen — and the nested compositor runs its own timers, animations and
`grabToImage` off those frames. Starve it and the suite does not slow down, it
waits for things that will never happen.

`float` because a tiling layout ignores a floating window, so nothing is
retiled, which was the original complaint. Not hidden: sending it to a hidden
special workspace looks tidier and took the suite from eleven seconds to every
stage reaching its timeout.

`pin` because floating is not enough on its own. A floating window still lives
on one workspace, and switching that monitor to another workspace unmaps it just
as thoroughly as hiding it. Measured during one 45-second run: the window sat on
workspace 6, the monitor spent 32 of those seconds showing workspace 4, and the
smoke test failed reporting that its image capture never completed — which was
exactly true. A pinned window follows the active workspace, so it stays drawn
while you work.

The cost is that it is visible on that monitor while the suite runs. That is the
trade, and it is not avoidable here: `hyprctl output create headless` would give
the nested session an output that renders regardless, but on Hyprland 0.56.2
that output comes up 0x0 and takes neither its one advertised mode nor
`preferred` from a monitor rule, and a zero-sized screen is worse than none
because the shell builds a bar on it.

Isolation is scoped to what the shell writes and what would disturb you: its
config directory, its cache, its runtime sockets, its bus, its compositor. What
it only reads — icon themes, GTK settings, desktop entries, PipeWire — stays
yours, linked back to the real thing. A session that cannot see those makes the
suite report the sandbox instead of the code.

One consequence worth knowing: an isolated run holds the smoke test to a
stricter standard than a normal one. On your own bus another shell already owns
`org.freedesktop.Notifications`, so `run-tests.sh` filters that warning out; on a
private bus the shell registers for real, and the filter is dropped so a
registration that stops working is caught rather than excused.

What it does not cover yet is the monitor count. The nested session has a single
output, so the `Variants` over `Quickshell.screens` only ever builds one bar —
`hyprctl output create headless` inside the session would let it cover
multi-monitor layouts without needing the hardware.
