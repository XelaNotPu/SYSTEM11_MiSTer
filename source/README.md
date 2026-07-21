# Namco System 11 for MiSTer

FPGA implementation of the [Namco System 11](https://en.wikipedia.org/wiki/Namco_System_11) arcade board for the [MiSTer platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki).

Namco System 11 (1994) is an arcade board built around Sony PlayStation technology: an R3000A-compatible MIPS CPU, a System 11 GPU (CXD8538Q) with 2 MB VRAM, and main RAM — paired with Namco-specific hardware that has no PlayStation equivalent: banked game ROM in place of a CD drive, a Namco C76 (Mitsubishi M37702) MCU handling sound and cabinet I/O, the Namco C352 32-voice PCM sound chip, and per-game KEYCUS protection chips. This core implements all of the above, including the C76 coprocessor and C352 sound.

The core is derived from the excellent [PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer) core by **Robert Peip (FPGAzumSpass)**, which provides the CPU, GPU, GTE, DMA, and memory subsystem foundation.

## Changes in this release (2026-07-20)

- **C76 interrupt delivery hardened** — the M37702 sound MCU now latches external
  INT0/INT1/INT2 with HOLD_LINE semantics, so it no longer drops the periodic
  60 Hz service interrupts under load. Improves sound-command and I/O reliability.
- **Soul Edge — dead Kick and Guard buttons fixed.** The P1 Kick input (driven
  onto IN1 BUTTON3 instead of being tied off) and the Guard input (P1 ADC2 /
  P2 PLAYER4) are now wired correctly, gated on the C409 KEYCUS so Tekken is
  unaffected. (Kick fix hardware-confirmed.)
- **My Angel 3 — quiz-panel button remap** so the four answer buttons register
  (per-game gated on the C443 KEYCUS).
- **Pocket Racer — analog steering/throttle plumbing corrected** (A-D result
  high byte and throttle-pedal polarity). Pocket Racer still does not boot into
  gameplay (a C76 shared-RAM handshake blocks it), but the analog path is now
  correct for when that boot issue is resolved.
- **Settings now save (EEPROM/nvram persistence).** The AT28C16 settings EEPROM
  is persisted to a `.nvm` file on the SD card, so test-menu options (difficulty,
  sound, coinage, high scores, ...) survive a power cycle. Note: Namco System 11
  test menus commit settings to EEPROM only when you **exit test mode** (turn the
  Service/Test switch off) — that write is what triggers the save.

This is a clean release: the forensic JTAG debug probes used during development
are not present in the shipped bitstream.

## Supported Games

| Game | Status | Notes |
|------|--------|-------|
| Tekken (World, TE2/VER.C) | **Playable** | Gameplay, sound effects, music, FMV intros and attract mode all work. Three regional alternates provided. |
| Tekken 2 Ver.B (World, TES2/VER.B) | **Playable** | Verified on hardware: boots, renders, music and inputs all work. All eight revisions ship (seven as alternates), each boot-tested. |
| Soul Edge Ver. II (SO4/VER.C) | Boots + attract | KEYCUS C409 |
| Dunk Mania (DM2/VER.C) | Boots + attract | KEYCUS C410; slow first boot (~2 min) |
| Xevious 3D/G (XV32/VER.B) | Boots + attract | KEYCUS C430 |
| Prime Goal EX (PG1/VER.A) | Boots + attract | KEYCUS C411 |
| Dancing Eyes (DC2/VER.B) | Boots + attract | KEYCUS C431 |
| Star Sweep (STP1/VER.A) | Boots + attract | KEYCUS C442 |
| Kosodate Quiz My Angel 3 (KQT1/VER.A) | Boots + attract | KEYCUS C443 + rom8_64 32 MB banking |

The seven new titles pass their KEYCUS protection checks and render their
attract sequences on hardware; gameplay depth-testing at the Tekken level is in
progress. **Pocket Racer** does not boot yet (a C76 shared-RAM handshake blocks
it — under investigation; its analog wheel plumbing is already in the core).
Point Blank 2 (lightgun; no ROM verified) and Family Bowl (H8/3002 sub-board)
are out of scope.

## Contents

```
RELEASE-20260720/
├── release/                       ← copy onto your MiSTer SD card
│   └── _Arcade/
│       ├── <one primary .mra per game (9 games)>
│       ├── _alternatives/
│       │   ├── _Tekken/           ← World VER.B, Asia VER.C, Japan VER.B
│       │   ├── _Tekken 2/         ← the other 7 revisions (incl. gameplay-verified World TES2-VER.D)
│       │   ├── _Soul Edge/        ← World/US/Japan VER.A, Ver. II US VER.C
│       │   ├── _Dunk Mania/       ← Japan DM1-VER.C
│       │   ├── _Xevious 3D-G/     ← World VER.A, Japan XV31-VER.A
│       │   ├── _Dancing Eyes/     ← US DC3-VER.C, Japan DC1-VER.A
│       │   └── _Star Sweep/       ← Japan STP1-VER.A
│       └── cores/
│           └── XNSYSTEM11_20260720.rbf   ← the FPGA core bitstream
└── source/                        ← full corresponding FPGA source (build it yourself)
```

## Installation

1. Copy `release/_Arcade/` to the `_Arcade/` folder on your MiSTer SD card
   (merging with what is already there).
2. Place your own ROM zips in the MiSTer arcade ROM location
   (`games/mame/` or `_Arcade/mame/`).
3. Select a game from the arcade menu.

The `.mra` files reference the core as `XNSYSTEM11`; MiSTer picks the
newest-dated `XNSYSTEM11_*.rbf` in `_Arcade/cores/`.

ROMs are **not** included with this project and are not linked from it — see [Legal](#legal). The MRA files reference MAME romsets by zip name:

| MRA | ROM zips required |
|-----|-------------------|
| Tekken (World TE2 Ver.C).mra | `tekken.zip` + `namcoc76.zip` |
| Tekken (World TE2 Ver.B).mra | `tekkenb.zip` + `tekken.zip` + `namcoc76.zip` |
| Tekken (Asia TE4 Ver.C).mra | `tekkenac.zip` + `tekken.zip` + `namcoc76.zip` |
| Tekken (Japan TE1 Ver.B).mra | `tekkenjb.zip` + `tekken.zip` + `namcoc76.zip` |
| Tekken 2 Ver.B (World TES2-VER.B).mra | `tekken2b.zip` (or merged `tekken2.zip`) + `namcoc76.zip` |
| Tekken 2 alternates (7 MRAs) | revision zip (`tekken2a/ua/ub/ud/jb/jc`) or merged `tekken2.zip`, + `namcoc76.zip` |
| Soul Edge Ver. II (SO4-VER.C).mra | `souledge.zip` + `namcoc76.zip` |
| Dunk Mania (DM2-VER.C).mra | `dunkmnia.zip` + `namcoc76.zip` |
| Xevious 3D-G (XV32-VER.B).mra | `xevi3dg.zip` + `namcoc76.zip` |
| Prime Goal EX (PG1-VER.A).mra | `primglex.zip` + `namcoc76.zip` |
| Dancing Eyes (DC2-VER.B).mra | `danceyes.zip` + `namcoc76.zip` |
| Star Sweep (STP1-VER.A).mra | `starswep.zip` + `namcoc76.zip` |
| Kosodate Quiz My Angel 3 (KQT1-VER.A).mra | `myangel3.zip` + `namcoc76.zip` |

`namcoc76.zip` (the Namco C76 sound-CPU BIOS) is required by **every** MRA — it is
loaded into the core at runtime and is not embedded in the bitstream.

The regional Tekken alternates and Tekken 2 declare their zip as a fallback list
(e.g. `tekkenb.zip|tekken.zip`): the loader checks the clone zip first and falls back
to the parent. Split/merged clone sets contain only the ROMs that differ from the
parent, so keep the parent zip alongside the clone unless you have non-merged sets.

Launch a game by selecting its MRA entry from the Arcade menu; the MRA loads the game program, banked data ROM, C76 sound program, and C352 wave ROM automatically.

## Controls

Tekken uses an 8-way joystick and four buttons per player, plus Start and Coin:

| Core button | Tekken function | Default pad mapping |
|-------------|-----------------|---------------------|
| Button 1 | Left Punch | A |
| Button 2 | Right Punch | B |
| Button 3 | Left Kick | X |
| Button 4 | Right Kick | Y |
| Buttons 5/6 | Unused by Tekken | L / R |
| Start | Start | Start |
| Coin | Insert coin | Select |
| Pause | Pause the core | L3 |

Two players are supported. The cabinet TEST and SERVICE switches are available as OSD toggles (see below), so the operator test menu can be reached without dedicated buttons.

## OSD Options

- **DIP Switches**
  - `DIP1 Test` — board test DIP
  - `DIP2 Freeze` — board freeze DIP
- **Debug**
  - `FPS Counter` — on-screen frame rate display
  - `Boot Debug Overlay` — diagnostic overlay during boot (off by default)
  - `Test Mode` — asserts the cabinet TEST switch (enters the operator test menu)
  - `Service Mode` — asserts the cabinet SERVICE switch (service credit)
- **Reset** — resets the board

Opening the OSD pauses the core. Video scaling/aspect options are currently handled by the MiSTer framework defaults; the core-specific video/audio option page is disabled in this release.

## Known Issues

- **Long-session display blank (under investigation)**: in extended soak testing, one
  build blanked its video output after ~100 minutes of continuous attract mode while
  the game itself kept running (sound/inputs alive, OSD works; a core reload restores
  the picture). Short and medium sessions are unaffected in testing.
- **Sound fidelity**: the C76/C352 sound engine plays correctly, but is still being
  tuned against real hardware. Feedback is welcome.
- **Pocket Racer** does not boot yet: the MIPS waits on a C76 shared-RAM handshake
  that never completes (KEYCUS is verified good — the exchange is bus-exact vs MAME in
  simulation). Analog wheel/pedal plumbing is already present for when it is fixed.
- All eight System 11 KEYCUS chips (C406, C409, C410, C411, C430, C431, C432, C442,
  C443) are implemented and hardware-verified. GPU type is selected per game
  (Tekken 1 = CXD8538Q/coh100; every other title = CXD8561Q/coh110, per MAME).
- **This core targets System 11 hardware only.** PlayStation console features inherited
  from the PSX_MiSTer base that System 11 does not use — memory cards, the SPU and the
  CD-ROM drive — are removed or stubbed to reclaim FPGA logic. The PSX controller port
  (SIO0) is a minimal register stub: several titles run stock PSX pad init at boot and
  need the port's registers to answer (as they do inside the CXD8530 on real boards),
  but no PlayStation controller protocol is implemented — arcade inputs are read by the
  C76 MCU.

## Hardware Requirements

A MiSTer with an **SDRAM module (64 MB minimum)** is required (up from 32 MB in the previous release). The core keeps the game program, banked data ROM (up to 32 MB with rom8_64 banking), C76 sound program, and C352 wave ROM (up to 4 MB) in SDRAM, with the load map extending to roughly 45 MB.

## Building from Source

The project targets **Quartus 17.0.x** (Lite Edition works). Open `SYSTEM11.qpf` and run a full compile, or from the command line:

```
quartus_sh --flow compile SYSTEM11
```

The output `output_files/SYSTEM11.rbf` should be renamed to
`XNSYSTEM11_20260720.rbf` when placed in `_Arcade/cores/`.

## Credits

- **Robert Peip (FPGAzumSpass)** — [PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer), the PlayStation core this project is built on. The CPU, GPU, GTE, and memory architecture are his work.
- **[MiSTer-devel](https://github.com/MiSTer-devel)** — the MiSTer framework, HPS I/O, and video pipeline.
- **[MAME](https://www.mamedev.org/)** project — the System 11 driver and device documentation used as the reference for the Namco-specific hardware (C76, C352, KEYCUS, ROM banking).
- **The MAME project** (smf et al.) — the Namco System 11 KEYCUS protection algorithms (C406, C409, …) reverse-engineered and documented in `ns11prot.cpp` (BSD-3-Clause); the KEYCUS logic in `s11_io.vhd` is an independent VHDL re-implementation of those documented algorithms.

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
