# Namco System 11 for MiSTer

FPGA implementation of the [Namco System 11](https://en.wikipedia.org/wiki/Namco_System_11) arcade board for the [MiSTer platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki).

Namco System 11 (1994) is an arcade board built around Sony PlayStation technology: an R3000A-compatible MIPS CPU, a System 11 GPU (CXD8538Q) with 2 MB VRAM, and main RAM — paired with Namco-specific hardware that has no PlayStation equivalent: banked game ROM in place of a CD drive, a Namco C76 (Mitsubishi M37702) MCU handling sound and cabinet I/O, the Namco C352 32-voice PCM sound chip, and per-game KEYCUS protection chips. This core implements all of the above, including the C76 coprocessor and C352 sound.

The core is derived from the excellent [PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer) core by **Robert Peip (FPGAzumSpass)**, which provides the CPU, GPU, GTE, DMA, and memory subsystem foundation.

## Supported Games

| Game | Status | Notes |
|------|--------|-------|
| Tekken (World, TE2/VER.C) | **Playable** | Gameplay, sound effects, music, FMV intros and attract mode all work. Three regional alternates provided. |
| Tekken 2 Ver.B (World, TES2/VER.D) | **Playable** | Primary is the final revision (boot-tested); the gameplay-verified World TES2/VER.B and six more revisions ship as alternates. |
| Soul Edge Ver. II (Asia, SO4/VER.C) | Boots + attract | KEYCUS C409 |
| Dunk Mania (World, DM2/VER.C) | Boots + attract | KEYCUS C410; slow first boot (~2 min) |
| Xevious 3D/G (World, XV32/VER.B) | Boots + attract | KEYCUS C430 |
| Prime Goal EX (Japan, PG1/VER.A) | Boots + attract | KEYCUS C411 |
| Dancing Eyes (World, DC2/VER.B) | Boots + attract | KEYCUS C431 |
| Star Sweep (World, STP2/VER.A) | Boots + attract | KEYCUS C442 |
| Kosodate Quiz My Angel 3 (Japan, KQT1/VER.A) | Boots + attract | KEYCUS C443 + rom8_64 32 MB banking |

The seven new titles pass their KEYCUS protection checks and render their
attract sequences on hardware; gameplay depth-testing at the Tekken level is in
progress. **Pocket Racer** does not boot yet (a C76 shared-RAM handshake blocks
it — under investigation; its analog wheel plumbing is already in the core).
Point Blank 2 (lightgun; no ROM verified) and Family Bowl (H8/3002 sub-board)
are out of scope.

## Installation

1. Copy `XNSYSTEM11_20260713.rbf` to `_Arcade/cores/` on your MiSTer SD card.
2. Copy the `.mra` files (e.g. `Tekken (World TE2 Ver.C).mra`) to `_Arcade/`.
3. Place the ROM zips in `games/mame/` (the standard MiSTer arcade ROM location).

ROMs are **not** included with this project and are not linked from it — see [Legal](#legal). The MRA files reference MAME romsets by zip name:

| MRA | ROM zips required |
|-----|-------------------|
| Tekken (World TE2 Ver.C).mra | `tekken.zip` + `namcoc76.zip` |
| Tekken (World TE2 Ver.B).mra | `tekkenb.zip` + `tekken.zip` + `namcoc76.zip` |
| Tekken (Asia TE4 Ver.C).mra | `tekkenac.zip` + `tekken.zip` + `namcoc76.zip` |
| Tekken (Japan TE1 Ver.B).mra | `tekkenjb.zip` + `tekken.zip` + `namcoc76.zip` |
| Tekken 2 Ver.B (World TES2-VER.D).mra | `tekken2.zip` + `namcoc76.zip` |
| Tekken 2 alternates (7 MRAs) | revision zip (`tekken2a/ua/ub/ud/jb/jc`) or merged `tekken2.zip`, + `namcoc76.zip` |
| Soul Edge Ver. II (Asia SO4-VER.C).mra | `souledge.zip` + `namcoc76.zip` |
| Dunk Mania (World DM2-VER.C).mra | `dunkmnia.zip` + `namcoc76.zip` |
| Xevious 3D-G (World XV32-VER.B).mra | `xevi3dg.zip` + `namcoc76.zip` |
| Prime Goal EX (Japan PG1-VER.A).mra | `primglex.zip` + `namcoc76.zip` |
| Dancing Eyes (World DC2-VER.B).mra | `danceyes.zip` + `namcoc76.zip` |
| Star Sweep (World STP2-VER.A).mra | `starswep.zip` + `namcoc76.zip` |
| Kosodate Quiz My Angel 3 (Japan KQT1-VER.A).mra | `myangel3.zip` + `namcoc76.zip` |
| Pocket Racer (Japan PKR1-VER.B).mra | `pocketrc.zip` + `namcoc76.zip` (not working yet) |
| Point Blank 2 (World GNB2-VER.A).mra | `ptblank2a.zip` (or merged `ptblank2.zip`) + `namcoc76.zip` (untested, no lightgun) |
| Family Bowl (Japan FB1-VER.A).mra | `fambowl.zip` + `namcoc76.zip` (not working) |

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
`XNSYSTEM11_20260713.rbf` when placed in `_Arcade/cores/`.

## Credits

- **Robert Peip (FPGAzumSpass)** — [PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer), the PlayStation core this project is built on. The CPU, GPU, GTE, and memory architecture are his work.
- **[MiSTer-devel](https://github.com/MiSTer-devel)** — the MiSTer framework, HPS I/O, and video pipeline.
- **[MAME](https://www.mamedev.org/)** project — the System 11 driver and device documentation used as the reference for the Namco-specific hardware (C76, C352, KEYCUS, ROM banking).
- **The MAME project** (smf et al.) — the Namco System 11 KEYCUS protection algorithms (C406, C409, …) reverse-engineered and documented in `ns11prot.cpp` (BSD-3-Clause); the KEYCUS logic in `s11_io.vhd` is an independent VHDL re-implementation of those documented algorithms.

## License

The combined work is conveyed under the **GNU General Public License, version 3 or (at your option) any later version** — see [LICENSE](LICENSE), with the full texts in [COPYING.GPL2](COPYING.GPL2) and [COPYING.GPL3](COPYING.GPL3).

Most of the tree — the PSX_MiSTer base by Robert Peip that this project derives from, and this project's own System 11 hardware implementations — is *GPLv2 or any later version*. However, several files inherited from the MiSTer framework and the PSX_MiSTer base (`rtl/hps_ext.v`, `rtl/ddram.sv`, `rtl/sdram.sv`, `sys/hps_io.sv`, `sys/scandoubler.v`, `sys/ddr_svc.sv`, `sys/sd_card.sv`) are *GPLv3 or any later version*. GPLv2-or-later code may be used under v3, but GPLv3 code cannot be conveyed under v2 — so the **combination** must be distributed under GPLv3+. Each individual file remains available to you under the terms stated in its own header.

`sys/ascal.vhd` (Avalon Scaler, TEMLIB) is distributed by its author under permissive, GPL-compatible terms. The Quartus-generated PLL wrappers carry Intel/Altera copyright notices and are redistributed as generated, as in every MiSTer core.

Any redistribution or derived work of this core carries the same obligations: ship the corresponding source, keep the license notices intact, and convey under GPLv3+.

## Legal

**No ROMs.** This repository contains no game ROMs and no copyrighted game data, and it provides no links or instructions for obtaining them. To use this core you must supply your own ROM dumps, made from original hardware or media that you legally own, where and to the extent your local law permits.

**Trademarks.** "Namco", "System 11", "Tekken", and related names and logos are trademarks or registered trademarks of Bandai Namco Entertainment Inc. and/or their respective owners. "PlayStation" is a trademark of Sony Interactive Entertainment Inc. This project is not affiliated with, endorsed by, or sponsored by Bandai Namco, Sony Interactive Entertainment, or any other rights holder. Such names are used here in a purely nominative and descriptive manner, solely to identify the hardware being re-implemented.

**Purpose.** This is an independent, non-commercial hardware-preservation and interoperability project. The FPGA logic is an original re-implementation of the System 11 board's behavior, developed from observation and from publicly available documentation and references (including the MAME project's hardware documentation); it contains no proprietary source code from the original manufacturers.

**Security-chip emulation.** Namco System 11 boards used per-game KEYCUS chips (C406, C409, …) as a protection measure. This core re-implements that logic for interoperability and preservation, in the same manner as MAME and comparable FPGA cores. The KEYCUS is a small challenge/response algorithm rather than stored key data, so no manufacturer key material is embedded in the bitstream. Laws such as the U.S. DMCA §1201 address circumvention of technological protection measures; whether and how they apply to this kind of preservation/interoperability use can depend on your jurisdiction and circumstances. Users are responsible for their own compliance.

**User responsibility.** Users are solely responsible for ensuring that their use of this core — including the acquisition and use of any ROM images — complies with copyright law and all other applicable laws in their jurisdiction.

**No warranty.** In accordance with the GPL-2.0 license: THIS PROGRAM IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU. IN NO EVENT WILL ANY COPYRIGHT HOLDER OR CONTRIBUTOR BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THIS PROGRAM, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
