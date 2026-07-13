# Namco System 11 for MiSTer — Release 2026-07-12

## Supported games

| Game | Set | Status |
|---|---|---|
| **Tekken** (1994) | World, TE2/VER.C | Playable — plus three regional alternates |
| **Tekken 2 Ver.B** (1995) | World, TES2/VER.B | Playable |

Only the two sets above are verified on hardware. **Other Tekken 2 revisions are
not included** — they are untested and some exhibit texture corruption that is
still under investigation. The remaining System 11 titles (Soul Edge, Xevious
3D/G, Dancing Eyes, Dunk Mania, Prime Goal EX, Star Sweep, Pocket Racer,
My Angel 3, Point Blank 2) are **not** supported in this build.

## Contents

```
RELEASE-20260712/
├── release/                       ← copy onto your MiSTer SD card
│   └── _Arcade/
│       ├── Tekken (World TE2 Ver.C).mra              ← Tekken (World, TE2/VER.C)
│       ├── Tekken 2 Ver.B (World TES2 Ver.B).mra     ← Tekken 2 Ver.B (World, TES2/VER.B)
│       ├── _alternatives/                            ← other Tekken regions/revisions
│       │   ├── Tekken (World TE2 Ver.B).mra
│       │   ├── Tekken (Asia TE4 Ver.C).mra
│       │   └── Tekken (Japan TE1 Ver.B).mra
│       └── cores/
│           └── XNSYSTEM11_20260712.rbf   ← the FPGA core bitstream
└── source/                        ← full FPGA core source (build it yourself)
```

## Installation

1. Copy `release/_Arcade/` to the `_Arcade/` folder on your MiSTer SD card
   (merging with what is already there).
2. Place your own ROM zips in the MiSTer arcade ROM location
   (`games/mame/` or `_Arcade/mame/`).
3. Select **Tekken** or **Tekken 2** from the arcade menu.

### Required ROM zips (you must supply these)

The `.mra` files reference standard MAME romsets **by name** — no game data is
included in this release. You must provide these, from ROM images you legally own.

#### Always required (every `.mra`, including the alternates)

**`tekken.zip`** — the parent romset (World, TE2/VER.C). The regional alternates
only carry their own unique program ROMs and fall back to this parent for
everything else, so **`tekken.zip` is required even when running an alternate.**

| ROM file(s) | What it is |
|---|---|
| `te2verc.2l`, `te2verc.2j`, `te1verb.2k`, `te1verb.2f` | Main program (interleaved) |
| `te1rom0l.ic5`, `te1rom0u.ic6`, `te1rom1l.ic3`, `te1rom1u.ic8`, `te1rom2l.ic4`, `te1rom2u.ic7` | Banked graphics/data ROMs |
| `te1sprog.6d` | C76 sound program |
| `te1wave.8k` | C352 PCM / wave data |

**`namcoc76.zip`** — Namco C76 (M37702) sound-CPU BIOS

| ROM file | What it is |
|---|---|
| `c76.bin` | C76 MCU internal BIOS (loaded at runtime, not embedded in the core) |

#### Additional zip per alternate

Each alternate in `_alternatives/` needs **one** extra zip, which supplies only
its unique main-program ROMs — the banked ROMs, sound program, and wave data all
come from `tekken.zip`:

| `.mra` | Additional zip | Unique ROMs it must contain |
|---|---|---|
| `Tekken (World TE2 Ver.B)` | `tekkenb.zip` | `te2verb.2l`, `te2verb.2j` |
| `Tekken (Asia TE4 Ver.C)` | `tekkenac.zip` | `te4verc.2l`, `te4verc.2j` |
| `Tekken (Japan TE1 Ver.B)` | `tekkenjb.zip` | `te1verb.2l`, `te1verb.2j` |

#### Tekken 2 Ver.B (World, TES2/VER.B)

`Tekken 2 Ver.B (World TES2 Ver.B).mra` needs **`tekken2b.zip`** (plus `namcoc76.zip`).
Tekken 2 uses its own `tes*` ROMs — none are shared with Tekken 1 — and has
**eight** banked ROMs rather than six.

| ROM file(s) | What it is |
|---|---|
| `tes2verb.2l`, `tes2verb.2j`, `tes1verb.2k`, `tes1verb.2f` | Main program (interleaved) |
| `tes1rom0l.ic6`, `tes1rom0u.ic5`, `tes1rom1l.ic8`, `tes1rom1u.ic3`, `tes1rom2l.ic7`, `tes1rom2u.ic4`, `tes1rom3l.ic9`, `tes1rom3u.ic1` | Banked graphics/data ROMs |
| `tes1sprog.6d` | C76 sound program |
| `tes1wave.8k` | C352 PCM / wave data |

As with the Tekken alternates, this MRA declares its zip as
`tekken2b.zip|tekken2.zip` — so if you have a *split/merged* clone set, keep the
Tekken 2 parent **`tekken2.zip`** alongside it, since a merged `tekken2b.zip`
carries only the ROMs that differ from the parent.

#### Summary — the complete set of zips

| Zip | Needed for |
|---|---|
| `namcoc76.zip` | **every** MRA (Tekken *and* Tekken 2) |
| `tekken.zip` | all Tekken MRAs (world release + every alternate) |
| `tekkenb.zip` | only `Tekken (World TE2 Ver.B)` |
| `tekkenac.zip` | only `Tekken (Asia TE4 Ver.C)` |
| `tekkenjb.zip` | only `Tekken (Japan TE1 Ver.B)` |
| `tekken2b.zip` | only `Tekken 2 Ver.B (World TES2 Ver.B)` |
| `tekken2.zip` | fallback for `tekken2b.zip` if you use split/merged sets |

Minimum to play **Tekken**: `tekken.zip` + `namcoc76.zip`.
Minimum to play **Tekken 2**: `tekken2b.zip` + `namcoc76.zip`.

## No copyrighted data

This release contains **no game ROMs and no copyrighted game data**:

- The core bitstream (`XNSYSTEM11_20260712.rbf`) embeds no BIOS, no sound program, no PCM
  data, and no captured nvram. The C76 sound-CPU BIOS is loaded at runtime from
  `namcoc76.zip`; the EEPROM initialises blank (all-`FF`) and self-configures.
- The `.mra` files reference romsets by name only — they contain no inline ROM
  data.
- The `source/` tree contains the original FPGA logic, standard PSX_MiSTer base
  RTL, hardware algorithm tables, and seperate pause-overlay artwork
- no game/BIOS/firmware images.

See `source/README.md` for the full legal notice, credits, trademark and
security-chip (KEYCUS) attribution, and build instructions.
