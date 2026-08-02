// KWin script: renumber virtual desktops sequentially from 1.
// API per KWin 6.7 docs:
//   - workspace.desktops: VirtualDesktop[] (all desktops, in order)
//   - VirtualDesktop.name: string (read-write)
//   - workspace.desktopsChanged(): emitted when a desktop is added or removed

function renumberDesktops() {
    const desktops = workspace.desktops;
    for (let i = 0; i < desktops.length; i++) {
        const expected = "Desktop " + (i + 1);
        if (desktops[i].name !== expected) {
            desktops[i].name = expected;
        }
    }
}

// Renumber once on startup.
renumberDesktops();

// Renumber whenever desktops are added or removed.
workspace.desktopsChanged.connect(renumberDesktops);
