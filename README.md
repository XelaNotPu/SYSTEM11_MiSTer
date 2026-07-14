<p align="center">
  <img src="art/XelaNotPu-LogoTransparent-GithubSocial.png" alt="SYSTEM11 MiSTer banner" width="100%">
</p>

# Namco System 11 for MiSTer — Release 2026-07-13

Nine playable System 11 titles — seven newly supported since the 2026-07-12
release, driven by four core fixes: per-game GPU type selection, the missing
M37702 `JML` opcode, all eight KEYCUS protection chips, and a SIO0 register
stub (plus 32 MB rom8_64 banking for My Angel 3).

## Supported games

| Game | Set | Status |
|---|---|---|
| **Tekken** (1994) | World, TE2/VER.C | Playable — verified gameplay, sound, inputs |
| **Tekken 2 Ver.B** (1996) | World, TES2/VER.D | Playable — the final revision; VER.B (gameplay-verified) and six more revisions ship as alternates |
| **Soul Edge Ver. II** (1996) | Asia, SO4/VER.C | New — boots, attract mode renders |
| **Dunk Mania** (1995) | World, DM2/VER.C | New — boots, attract mode renders (slow first boot, ~2 min) |
| **Xevious 3D/G** (1995) | World, XV32/VER.B | New — boots, attract mode renders |
| **Prime Goal EX** (1996) | Japan, PG1/VER.A | New — boots, attract mode renders |
| **Dancing Eyes** (1996) | World, DC2/VER.B | New — boots, attract mode renders |
| **Pocket Racer** (1996) | Japan, PKR1/VER.B | **Not working** — C76 handshake blocks boot, under investigation |
| **Star Sweep** (1997) | World, STP2/VER.A | New — boots, attract mode renders |
| **Kosodate Quiz My Angel 3** (1998) | Japan, KQT1/VER.A | New — boots, attract mode renders (first title using 32 MB rom8_64 banking) |
| **Point Blank 2** (1999) | World, GNB2/VER.A | **Untested** — MRAs provided; needs a lightgun, which the core does not implement yet |
| **Family Bowl** (1997) | Japan, FB1/VER.A | **Not working** — needs an H8/3002 sub-board that is not emulated (not working in MAME either) |

The seven new titles are verified to boot and render their attract sequences on
hardware; gameplay, sound and input depth-testing at the level done for the two
Tekkens is still in progress.

**Full region coverage**: every System 11 romset known to MAME has an MRA in
this release — one primary per game in `_Arcade/`, with regional/revision
alternates under `_Arcade/_alternatives/_<Game>/`. All eight Tekken 2 revisions
were boot-tested on hardware. The **alternate sets of the seven new titles**
(Soul Edge, Xevious 3D/G, Dancing Eyes, Dunk Mania, Star Sweep regions) are
generated from MAME ROM definitions but have **not** been individually
boot-tested.

## Contents

```
RELEASE-20260713/
├── release/                       ← copy onto your MiSTer SD card
│   └── _Arcade/
│       ├── <one primary .mra per game (12 games)>
│       ├── _alternatives/
│       │   ├── _Tekken/           ← World VER.B, Asia VER.C, Japan VER.B
│       │   ├── _Tekken 2/         ← the other 7 revisions (incl. gameplay-verified World TES2-VER.B)
│       │   ├── _Soul Edge/        ← US VER.C, World/US/Japan VER.A
│       │   ├── _Dunk Mania/       ← Japan DM1-VER.C
│       │   ├── _Xevious 3D-G/     ← World VER.A, Japan XV31-VER.A
│       │   ├── _Dancing Eyes/     ← US DC3-VER.C, Japan DC1-VER.A
│       │   ├── _Star Sweep/       ← Japan STP1-VER.A
│       │   └── _Point Blank 2/    ← World alt sets, US GNB3-VER.A, Gunbarl (Japan)
│       └── cores/
│           └── XNSYSTEM11_20260713.rbf   ← the FPGA core bitstream
└── source/                        ← full FPGA core source (build it yourself)
```

## Installation

1. Copy `release/_Arcade/` to the `_Arcade/` folder on your MiSTer SD card
   (merging with what is already there).
2. Place your own ROM zips in the MiSTer arcade ROM location
   (`games/mame/` or `_Arcade/mame/`).
3. Select a game from the arcade menu.

If you installed RELEASE-20260712, the new core and MRAs coexist with it;
the `.mra` files reference the core as `XNSYSTEM11` and MiSTer picks the
newest dated `XNSYSTEM11_*.rbf` in `_Arcade/cores/`.

## Hardware requirements

A MiSTer with a **64 MB (or larger) SDRAM module** is required — up from
32 MB in the previous release. The rom8_64 banking support moved the C76
sound program and C352 wave data above the 40 MB mark for **all** titles.
With a 32 MB module the games will run silent at best.

## ROM zips required

No ROMs are included. Each MRA references MAME romsets by zip name;
`namcoc76.zip` (the C76 sound-CPU BIOS, loaded at runtime) is needed by
**every** MRA.

| Game (primary MRA) | Zips |
|---|---|
| Tekken | `tekken.zip` + `namcoc76.zip` |
| Tekken 2 Ver.B | `tekken2b.zip` (or merged `tekken2.zip`) + `namcoc76.zip` |
| Soul Edge Ver. II | `souledge.zip` + `namcoc76.zip` |
| Dunk Mania | `dunkmnia.zip` + `namcoc76.zip` |
| Xevious 3D/G | `xevi3dg.zip` + `namcoc76.zip` |
| Prime Goal EX | `primglex.zip` + `namcoc76.zip` |
| Dancing Eyes | `danceyes.zip` + `namcoc76.zip` |
| Star Sweep | `starswep.zip` + `namcoc76.zip` |
| My Angel 3 | `myangel3.zip` + `namcoc76.zip` |
| Pocket Racer | `pocketrc.zip` + `namcoc76.zip` |
| Point Blank 2 | `ptblank2a.zip` (or merged `ptblank2.zip`) + `namcoc76.zip` |
| Family Bowl | `fambowl.zip` + `namcoc76.zip` |

Alternates: each alternate MRA declares its own clone zip with a fallback to
the parent (e.g. `souledgeja.zip|souledge.zip`), so a **merged parent zip
satisfies every alternate of that game**. Clone zips from split/merged sets
contain only the ROMs that differ — keep the parent zip alongside them.

## Known issues

- **Long-session display blank (under investigation).** In extended soak
  testing, one build blanked its video output after ~100 minutes of
  continuous attract mode while the game itself kept running (sound and
  inputs stay alive; the OSD still works). Reloading the core restores the
  picture. The root cause is being investigated; short and medium play
  sessions are unaffected in testing.
- **Dunk Mania boots slowly** (~2 minutes to first picture on a fresh
  EEPROM). This matches its first-boot initialization; subsequent boots are
  faster.
- **New titles are attract-verified.** Gameplay/sound/input verification at
  full depth exists for Tekken and Tekken 2; the seven new titles have been
  verified to boot, pass their protection checks, and render attract mode.
- **Pocket Racer** does not boot yet: the MIPS waits on a C76 shared-RAM
  handshake that never completes. Its MRA is included for completeness. The
  analog wheel plumbing (steering on the left stick / paddle, pedal on
  Button 1) is already in the core for when the handshake issue is resolved.
- **Point Blank 2 / Gunbarl** MRAs are provided untested: the core has no
  lightgun support yet, and these sets were not boot-tested.
- **Family Bowl** does not work (unemulated H8/3002 sub-board; not working
  in MAME either). Its MRA is included for completeness only.
- **Sound fidelity** continues to be tuned against real hardware.

## No copyrighted data

This release contains **no game ROMs and no copyrighted game data**:

- The core bitstream (`XNSYSTEM11_20260713.rbf`) embeds no BIOS, no sound
  program, no PCM data, and no captured nvram. The C76 sound-CPU BIOS is
  loaded at runtime from `namcoc76.zip`; the EEPROM initialises blank
  (all-`FF`) and self-configures.
- The `.mra` files reference romsets by name only — they contain no inline
  ROM data.
- The `source/` tree contains the original FPGA logic, standard PSX_MiSTer
  base RTL, hardware algorithm tables, and the author's own pause-overlay
  artwork — no game/BIOS/firmware images.

## License

The core and its source are Free Software, conveyed under the **GNU General
Public License v3 or later** (the tree mixes GPLv2-or-later and GPLv3-or-later
files, so the combination is GPLv3+; every file remains available under the
terms in its own header). Full texts ship in `source/COPYING.GPL2` and
`source/COPYING.GPL3`, with the reasoning in `source/LICENSE`.

This core derives from **PSX_MiSTer** by Robert Peip (FPGAzumSpass) and the
**MiSTer framework**; the System 11 hardware (C76, C352, KEYCUS, ROM banking)
is an independent re-implementation developed with reference to the MAME
project's hardware documentation.

See `source/README.md` for the full legal notice, credits, trademark and
security-chip (KEYCUS) attribution, and build instructions.

## Legal

No ROMs. This repository contains no game ROMs and no copyrighted game data, and it provides no links or instructions for obtaining them. To use this core you must supply your own ROM dumps, made from original hardware or media that you legally own, where and to the extent your local law permits.

Trademarks. "Namco", "System 11", "Tekken", and related names and logos are trademarks or registered trademarks of Bandai Namco Entertainment Inc. and/or their respective owners. "PlayStation" is a trademark of Sony Interactive Entertainment Inc. This project is not affiliated with, endorsed by, or sponsored by Bandai Namco, Sony Interactive Entertainment, or any other rights holder. Such names are used here in a purely nominative and descriptive manner, solely to identify the hardware being re-implemented.

Purpose. This is an independent, non-commercial hardware-preservation and interoperability project. The FPGA logic is an original re-implementation of the System 11 board's behavior, developed from observation and from publicly available documentation and references (including the MAME project's hardware documentation); it contains no proprietary source code from the original manufacturers.

Security-chip emulation. Namco System 11 boards used per-game KEYCUS chips (C406, C409, …) as a protection measure. This core re-implements that logic for interoperability and preservation, in the same manner as MAME and comparable FPGA cores. The KEYCUS is a small challenge/response algorithm rather than stored key data, so no manufacturer key material is embedded in the bitstream. Laws such as the U.S. DMCA §1201 address circumvention of technological protection measures; whether and how they apply to this kind of preservation/interoperability use can depend on your jurisdiction and circumstances. Users are responsible for their own compliance.

User responsibility. Users are solely responsible for ensuring that their use of this core — including the acquisition and use of any ROM images — complies with copyright law and all other applicable laws in their jurisdiction.

No warranty. In accordance with the GPL-2.0 license: THIS PROGRAM IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU. IN NO EVENT WILL ANY COPYRIGHT HOLDER OR CONTRIBUTOR BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THIS PROGRAM, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
