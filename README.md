<p align="center">
  <img src="art/XelaNotPu-LogoTransparent-GithubSocial.png" alt="SYSTEM11 MiSTer banner" width="100%">
</p>

# Namco System 11 for MiSTer

FPGA implementation of the [Namco System 11](https://en.wikipedia.org/wiki/Namco_System_11) arcade board for the [MiSTer platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki).

Namco System 11 (1994) is an arcade board built around Sony PlayStation technology: an R3000A-compatible MIPS CPU, a System 11 GPU (CXD8538Q) with 2 MB VRAM, and main RAM — paired with Namco-specific hardware that has no PlayStation equivalent: banked game ROM in place of a CD drive, a Namco C76 (Mitsubishi M37702) MCU handling sound and cabinet I/O, the Namco C352 32-voice PCM sound chip, and per-game KEYCUS protection chips. This core implements all of the above, including the C76 coprocessor and C352 sound.

The core is derived from the excellent [PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer) core by **Robert Peip (FPGAzumSpass)**, which provides the CPU, GPU, GTE, DMA, and memory subsystem foundation.

## New in 20260911

- **The OSD no longer pauses the game by default.** A new OSD option —
  **"Pause when OSD is open"** (default **Off**) — controls it: leave it Off and
  the game keeps running, sound and all, while you're in the menu; switch it On
  to get the old freeze-on-menu behavior back. The mappable Pause button is
  unchanged.

The core file is `Arcade-SYSTEM11_20260911b.rbf` (the "b" keeps it after — and
distinct from — the same-day supporter build in MiSTer's version-name sorting).
Everything below from 20260901 carries over unchanged.

## New in 20260901

This is the **standard edition** of the core. It carries the full 20260818 core content —
the C352 audio fix across all twelve titles, the cleaned-up source tree, the retired "XN"
prefix, and the all-clocks-positive timing closure — trimmed to a lean, play-only build:

- Two supporter-edition hardware features (CRT Adjust and DB9/DB15 joystick support)
  are not included. Because the user-port pin those features borrowed is back on its
  original duty, the **secondary SPI-SD add-on works again** with this edition.
- The pause/credits overlay screen is not included; pausing (button or OSD) simply
  freezes the core on the last game frame.
- All development/debug instrumentation is stripped from the bitstream and the OSD:
  no Debug menu page, no FPS counter, no boot-debug overlay, and no JTAG probe logic.
  The DIP-switch Test entry on the DIP Switches page remains for operator settings.

Also in this release:

- **Tekken 2 alternate revisions fixed**: the six older revisions (TES1/TES2/TES3
  VER.A/B/C) run on the coh100 board with the earlier CXD8538Q GPU; the core now
  selects the correct GPU type for them via their MRAs, fixing the corrupt
  graphics those versions showed. The primary TES2-VER.D (and TES3-VER.D) were
  always correct.
- **Accurate cabinet inputs**: both physical DIP switches are exposed with MAME's
  exact names — "DIP1 (Test)" enters each game's service menu, "DIP2 (Freeze)"
  freezes — and the cabinet Service button is now mappable (OSD → Define buttons),
  so service menus are fully operable.
- **Game-appropriate button labels**: every MRA names its buttons for its game
  (Tekken LP/RP/LK/RK, Soul Edge Horizontal/Vertical/Kick/Guard, Point Blank 2
  Trigger, My Angel 3 Answer 1-4, and so on).
- **Light-gun options only for light-gun games**: the Light Gun OSD page and gun
  input now appear only for Point Blank 2 and Gunbarl.

If you installed an earlier build, delete any old `XNSYSTEM11*.rbf` from `_Arcade/cores/`
and replace your MRAs with this release's set (the old MRAs point at the old name).

## Games

Primary titles (one per game; other regions/revisions live in `releases/_Arcade/_alternatives/_<Game>/`):

- Tekken (TE2 Ver.C)
- Tekken 2 Ver.B (TES2-VER.D)
- Soul Edge Ver. II (SO4-VER.C)
- Xevious 3D/G (XV32-VER.B)
- Dunk Mania (DM2-VER.C)
- Prime Goal EX (PG1-VER.A)
- Dancing Eyes (DC2-VER.B)
- Star Sweep (STP1-VER.A)
- Kosodate Quiz My Angel 3 (KQT1-VER.A)
- Pocket Racer (Japan PKR1-VER.B)
- Point Blank 2 (World GNB2-VER.A)
- Gunbarl (Japan GNB1-VER.A)

*(+24 alternate region/revision MRAs under `releases/_Arcade/_alternatives/`; Gunbarl, the Japanese release of Point Blank 2, ships under `_alternatives/_Point Blank 2/`.)*
**Family Bowl** remains out of scope

## Controls

Standard System 11 controls (up to 4 buttons in the P1 register, plus coin/start). Labels come from each MRA's `<buttons>` tag. Supports keyboard and USB joystick input.

## Install

Copy the `_Arcade/` folder onto your SD card's root folder: this places the `.mra` files (and `_alternatives/`) directly in `_Arcade/`, and `cores/Arcade-SYSTEM11_20260911b.rbf` in `_Arcade/cores/`. **Remove stale `XNSYSTEM11_*` cores and MRAs from earlier builds** — they reference the retired name. **Provide your own romsets — nothing copyrighted is included.**

MRAs reference romsets by name only.

### A note on MRA load layout

These MRAs use one ROM stream per hardware region (program / banked data / sound program /
wave), which is the layout this core's loader is built around: each stream has its own
SDRAM base and address window in the loader hardware. A concatenated single-stream "fast
load" MRA layout is **not** used here because the core routes downloads strictly by stream
index — the program window wraps at 4 MB, so a single 24 MB+ concatenated stream would
self-overwrite — and the fixed offsets such a layout assumes do not match this core's SDRAM
map. Adopting it would require loader RTL changes and a re-verification of every title's
load path; until then the per-region layout remains the correct, verified one.

## Credits & attribution

This core stands on the work of others, gratefully acknowledged:

- **PSX_MiSTer** by **Robert Peip (FPGAzumSpass)** — the PlayStation core this System 11 core derives from, providing the R3000A CPU, GPU, GTE, DMA, and memory subsystem.
- **The MiSTer project** and its framework (`sys/`) — Alexey Melnikov (**Sorgelig**) and the MiSTer-devel contributors.
- **C76 M37702 / C352 / KEYCUS** — original FPGA re-implementations of System 11's sound and security hardware.
- **The MAME project** — the hardware documentation and reference behavior used to develop System 11 board support (per-manufacturer boot ROM, CAT702 security, ROM banking, NVRAM/EEPROM) as an independent re-implementation.
- **System 11 hardware and chipset re-implementations** — **XelaNotPu**: the System 11 hardware (per-manufacturer boot ROM, CAT702 security, ROM banking, NVRAM/EEPROM), the sound-chip re-implementations (C76 M37702, C352), and the XN README banner artwork.

## License

This core is a combined/derived work licensed under the **GNU General Public License, version 3 or later (GPLv3-or-later)**.

It builds on [PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer) (Robert Peip) and the MiSTer framework. Several files in the build tree — the MiSTer `sys/` HPS-I/O, SD-card, scandoubler and DDR-service modules, and the SDRAM/DDR memory controllers — are licensed **GPL version 3 or later**. Combining GPLv2-or-later code with GPLv3-or-later code yields a work that can only be conveyed under GPLv3-or-later, so that is the license of this core as a whole. The full texts of both licenses are included (`COPYING.GPL2`, `COPYING.GPL3`); GPLv2-or-later files remain individually available under their own terms.

## Legal

**No ROMs.** This repository contains no game ROMs and no copyrighted game data, and it provides no links or instructions for obtaining them. To use this core you must supply your own ROM dumps, made from original hardware or media that you legally own, where and to the extent your local law permits.

**Trademarks.** "Namco", "System 11", "Tekken", and related names and logos are trademarks or registered trademarks of Bandai Namco Entertainment Inc. and/or their respective owners. "PlayStation" is a trademark of Sony Interactive Entertainment Inc. This project is not affiliated with, endorsed by, or sponsored by Bandai Namco, Sony Interactive Entertainment, or any other rights holder. Such names are used here in a purely nominative and descriptive manner, solely to identify the hardware being re-implemented.

**Purpose.** This is an independent, non-commercial hardware-preservation and interoperability project. The FPGA logic is an original re-implementation of the System 11 board's behavior, developed from observation and from publicly available documentation and references (including the MAME project's hardware documentation); it contains no proprietary source code from the original manufacturers.

**Security-chip emulation.** Namco System 11 boards used per-game KEYCUS chips (C406, C409, …) as a protection measure. This core re-implements that logic for interoperability and preservation, in the same manner as MAME and comparable FPGA cores. The KEYCUS is a small challenge/response algorithm rather than stored key data, so no manufacturer key material is embedded in the bitstream. Laws such as the U.S. DMCA §1201 address circumvention of technological protection measures; whether and how they apply to this kind of preservation/interoperability use can depend on your jurisdiction and circumstances. Users are responsible for their own compliance.

**User responsibility.** Users are solely responsible for ensuring that their use of this core — including the acquisition and use of any ROM images — complies with copyright law and all other applicable laws in their jurisdiction.

**No warranty.** As set out in sections 15–16 of the GNU General Public License (v3) and the equivalent clauses of v2: THIS PROGRAM IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU. IN NO EVENT WILL ANY COPYRIGHT HOLDER OR CONTRIBUTOR BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THIS PROGRAM, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
