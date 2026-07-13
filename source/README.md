# Namco System 11 for MiSTer

FPGA implementation of the [Namco System 11](https://en.wikipedia.org/wiki/Namco_System_11) arcade board for the [MiSTer platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki).

Namco System 11 (1994) is an arcade board built around Sony PlayStation technology: an R3000A-compatible MIPS CPU, a System 11 GPU (CXD8538Q) with 2 MB VRAM, and main RAM — paired with Namco-specific hardware that has no PlayStation equivalent: banked game ROM in place of a CD drive, a Namco C76 (Mitsubishi M37702) MCU handling sound and cabinet I/O, the Namco C352 32-voice PCM sound chip, and per-game KEYCUS protection chips. This core implements all of the above, including the C76 coprocessor and C352 sound.

The core is derived from the excellent [PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer) core by **Robert Peip (FPGAzumSpass)**, which provides the CPU, GPU, GTE, DMA, and memory subsystem foundation.

## Supported Games

| Game | Status | Notes |
|------|--------|-------|
| Tekken (World, TE2/VER.C) | **Playable** | Gameplay, sound effects, music, FMV intros and attract mode all work. Three regional alternates are also provided (World TE2/VER.B, Asia TE4/VER.C, Japan TE1/VER.B). |
| Tekken 2 Ver.B (World, TES2/VER.B) | **Playable** | Verified on hardware: boots, renders, music and inputs all work. |

**Only the two sets above are verified.** Other Tekken 2 revisions (including the
TES2/VER.D parent) are **not** included: they are untested, and some exhibit
texture corruption that is still under investigation. The corruption appears to be
revision-specific rather than affecting the whole Tekken 2 family.

Other System 11 titles (Soul Edge, Xevious 3D/G, Dancing Eyes, Dunk Mania, Prime
Goal EX, Star Sweep, Pocket Racer, My Angel 3, Point Blank 2) are future work and
are **not** supported by this build. Each needs at least its own KEYCUS chip
implemented; some additionally need ROM8(64) banking, a lightgun, or analog inputs.

## Installation

1. Copy `XNSYSTEM11_20260712.rbf` to `_Arcade/cores/` on your MiSTer SD card.
2. Copy the `.mra` files (e.g. `Tekken (World TE2 Ver.C).mra`) to `_Arcade/`.
3. Place the ROM zips in `games/mame/` (the standard MiSTer arcade ROM location).

ROMs are **not** included with this project and are not linked from it — see [Legal](#legal). The MRA files reference MAME romsets by zip name:

| MRA | ROM zips required |
|-----|-------------------|
| Tekken (World TE2 Ver.C).mra | `tekken.zip` + `namcoc76.zip` |
| Tekken (World TE2 Ver.B).mra | `tekkenb.zip` + `tekken.zip` + `namcoc76.zip` |
| Tekken (Asia TE4 Ver.C).mra | `tekkenac.zip` + `tekken.zip` + `namcoc76.zip` |
| Tekken (Japan TE1 Ver.B).mra | `tekkenjb.zip` + `tekken.zip` + `namcoc76.zip` |
| Tekken 2 Ver.B (World TES2 Ver.B).mra | `tekken2b.zip` + `namcoc76.zip` |

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

- **Other Tekken 2 revisions** (TES2/VER.D parent, US and Japan sets) are untested and
  are not shipped. Some show texture corruption; the shipped World TES2/VER.B set does
  not. The issue looks revision-specific and is still under investigation.
- **Sound fidelity**: the C76/C352 sound engine plays correctly, but is still being
  tuned against real hardware. Feedback is welcome.
- Only the Tekken-family KEYCUS chips are handled so far (Tekken needs none; Tekken 2's
  C406 is emulated). The other titles' KEYCUS chips (C409, C410, C411, C430, C431, C432,
  C442, C443) are not yet implemented.
- **This core targets System 11 hardware only.** PlayStation console features inherited
  from the PSX_MiSTer base that System 11 does not use — the PSX controller port (SIO0),
  memory cards, the SPU and the CD-ROM drive — are removed or stubbed to reclaim FPGA
  logic. System 11 needs none of them: arcade inputs are read by the C76 MCU, game data
  comes from banked ROM rather than a CD, and audio is produced by the C352.

## Hardware Requirements

A MiSTer with an **SDRAM module (32 MB minimum)** is required. The core keeps the game program, banked data ROM (up to 16 MB), C76 sound program, and C352 wave ROM (up to 4 MB) in SDRAM, with the load map extending to roughly 30 MB.

## Building from Source

The project targets **Quartus 17.0.x** (Lite Edition works). Open `SYSTEM11.qpf` and run a full compile, or from the command line:

```
quartus_sh --flow compile SYSTEM11
```

The output `XNSYSTEM11_20260712.rbf` appears in `output_files/`.

## Credits

- **Robert Peip (FPGAzumSpass)** — [PSX_MiSTer](https://github.com/MiSTer-devel/PSX_MiSTer), the PlayStation core this project is built on. The CPU, GPU, GTE, and memory architecture are his work.
- **[MiSTer-devel](https://github.com/MiSTer-devel)** — the MiSTer framework, HPS I/O, and video pipeline.
- **[MAME](https://www.mamedev.org/)** project — the System 11 driver and device documentation used as the reference for the Namco-specific hardware (C76, C352, KEYCUS, ROM banking).
- **The MAME project** (smf et al.) — the Namco System 11 KEYCUS protection algorithms (C406, C409, …) reverse-engineered and documented in `ns11prot.cpp` (BSD-3-Clause); the KEYCUS logic in `s11_io.vhd` is an independent VHDL re-implementation of those documented algorithms.

## License

This project is licensed under the **GNU General Public License, version 2 (GPL-2.0)** — see the [LICENSE](LICENSE) file. It is a derived work of PSX_MiSTer by Robert Peip, and the upstream license terms carry over to this project; the same terms apply to any redistribution or derived work of this core.

## Legal

**No ROMs.** This repository contains no game ROMs and no copyrighted game data, and it provides no links or instructions for obtaining them. To use this core you must supply your own ROM dumps, made from original hardware or media that you legally own, where and to the extent your local law permits.

**Trademarks.** "Namco", "System 11", "Tekken", and related names and logos are trademarks or registered trademarks of Bandai Namco Entertainment Inc. and/or their respective owners. "PlayStation" is a trademark of Sony Interactive Entertainment Inc. This project is not affiliated with, endorsed by, or sponsored by Bandai Namco, Sony Interactive Entertainment, or any other rights holder. Such names are used here in a purely nominative and descriptive manner, solely to identify the hardware being re-implemented.

**Purpose.** This is an independent, non-commercial hardware-preservation and interoperability project. The FPGA logic is an original re-implementation of the System 11 board's behavior, developed from observation and from publicly available documentation and references (including the MAME project's hardware documentation); it contains no proprietary source code from the original manufacturers.

**Security-chip emulation.** Namco System 11 boards used per-game KEYCUS chips (C406, C409, …) as a protection measure. This core re-implements that logic for interoperability and preservation, in the same manner as MAME and comparable FPGA cores. The KEYCUS is a small challenge/response algorithm rather than stored key data, so no manufacturer key material is embedded in the bitstream. Laws such as the U.S. DMCA §1201 address circumvention of technological protection measures; whether and how they apply to this kind of preservation/interoperability use can depend on your jurisdiction and circumstances. Users are responsible for their own compliance.

**User responsibility.** Users are solely responsible for ensuring that their use of this core — including the acquisition and use of any ROM images — complies with copyright law and all other applicable laws in their jurisdiction.

**No warranty.** In accordance with the GPL-2.0 license: THIS PROGRAM IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU. IN NO EVENT WILL ANY COPYRIGHT HOLDER OR CONTRIBUTOR BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THIS PROGRAM, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
