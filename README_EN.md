# FZS1 CPE — Cloud-Control Removal & Local Feature Enhancement

> Completely removes the vendor cloud-control system from the **蜂助手 S1 (MIBOX-668M2)** CPE,
> while preserving and enhancing all local functionality.
> One package replacement + reboot gives you: **cloud-free operation + IMEI changer + band lock + cell/frequency lock + device dashboard**.

> **Note:** This is the English version. The Chinese version is available at [README.md](README.md).

**Scope and keywords** (for search):
`ASR platform` (ASR1802 / ASR1803, ASR Microelectronics), `Quectel EC200T` / `EC200N` / `EC200A`,
`AT*BAND` (band lock), `AT*CELL` (frequency lock / cell lock), `EARFCN`, `PCI`,
`AT+QENG="servingcell"`, `MT7628` 4G CPE, `蜂助手 S1` / `MIBOX-668M2`.

> 📄 **Here only for the modem / AT commands?** See the standalone document —
> **[ASR Platform LTE Modem AT Commands: Band / Frequency / Cell Lock](ASR-AT-Commands-Band-Cell-Lock.md)**
> (English) ｜ [中文](ASR平台AT命令-锁频段锁频点锁小区.md)

> ⚠️ **Please read the [Disclaimer](#disclaimer) before use. This project involves modifying the IMEI, which is legally regulated in most countries and regions. Use it only on devices you legally own.**

> 💚 **This project is completely free and open source. There is no paid content of any kind.** We do not sell devices, do not sell services, do not offer a "paid edition", and accept no donations or sponsorships. If you **paid money** for this firmware or this guide, **you were scammed** — demand a refund from the seller, and please report them via a repository Issue. See [About Pricing](#about-pricing).

---

**The toolbox UI** (dashboard / ① IMEI changer / ② band lock / ③ cell & frequency lock / ④ admin password):

![Toolbox UI](images/toolbox.png)

## Hardware Overview

| Item | Specification |
|---|---|
| Model | 蜂助手 S1 (MIBOX-668M2) |
| SoC | MediaTek MT7628DAN |
| OS | OpenWrt Barrier Breaker 14.07 / Kernel 3.10.14 |
| Storage | 8 MB flash / 64 MB RAM |
| Main modem | Quectel EC200T (LTE Cat.4) |
| Cloud SIM module | Quectel EC200N (LTE Cat.1, embedded chip SIM) |

These devices ship with a **Dinstar cloud-control system** pre-installed: it provisions a virtual SIM from the vendor platform over the Cat.1 cloud-SIM channel (the data uplink rides on the Cat.4 modem), uploads logs, and accepts remote OTA and rate-limiting commands. This project removes that system, turning the device into a **fully self-owned 4G router**.

---

## Hardware Notes (read this first — SIM mod required)

The device ships in two hardware variants, and **both share one missing part** that must be handled before a physical SIM card can be used:

| Variant | Mod required |
|---|---|
| **With SIM slot** | The SIM slot is soldered, but the **U10 component position is unpopulated** — open it up and bridge/solder the U10 pads as shown below |
| **Without SIM slot** | **No SIM slot at all** — solder one yourself, **and handle U10 the same way** |

**U10 soldering guide** (next to silkscreen `U10`, near C107 / R149 / R829 / R832 / R833; the red 1/2/3/4 marks the pin positions):

![U10 soldering](images/u10-solder.jpg)

- Without U10 handled, **a physical SIM card is not detected** (a common cause of "no service after inserting a card")
- **Soldering carries risk**: a short can make the whole USB bus disappear (modem and hub both gone). Ground your iron and check for bridges before powering on
- The GL850G USB hub exposes one port from the factory; the second can be wired for USB dongles etc.
- Unstable power to USB dongles can cause reboots — add a capacitor or use separate power
- The converted LAN→WAN port needs a switch VLAN configured in OpenWrt

---

## Quick Start

> **Page names used throughout this document**: the **Device Admin Page** = open `http://192.168.1.1` (the stock panel, admin/admin); the **LuCI panel** = `http://192.168.1.1:8888` (full OpenWrt UI); the **Toolbox** = `http://192.168.1.1:8088` (added by this project).

### Requirements

- **Hardware mod completed** (SIM slot + U10, see above) — otherwise no SIM service and this project has nothing to offer
- Device boots normally (stock system)
- Computer on the same LAN (device at `192.168.1.1`)
- Note: the **recommended method (admin page upload) does not require internet access** on the device

### Which package to download?

**The repo root only carries the two latest packages** — pick by install method:

| File | Size | Method |
|---|---|---|
| **`package-full.tar.gz`** | 2.4 MB | **Device Admin Page → Software Upgrade (recommended)** |
| `package-slim.tar.gz` | 1.2 MB | System command line / telnet (methods A/C, smaller) |

> Both packages are **functionally identical**; `full` just embeds a copy of itself (the stock upgrade interface requires that format).
> **Do not mix them up**: admin-page upload requires `full`; command line requires `slim`.
>
> Old versions and the factory-restore package live in subfolders: [`历史版本/`](历史版本/) (v19.4, v19 archives), [`恢复原厂包/`](恢复原厂包/) (to return the device to stock).

---

### Method B (recommended): Device Admin Page → Software Upgrade

Beginner-friendly: all in the browser, **no device internet needed**, especially friendly for brand-new or second-hand units.

1. Download `package-full.tar.gz` from this repo to your computer
2. Open `http://192.168.1.1` in a browser, admin/admin
3. Menu → **软件升级 (Software Upgrade)** → select `package-full.tar.gz` → click「加载 (Load)」
4. The device reboots automatically (about 1–2 minutes)

> ⚠️ This method **requires `package-full.tar.gz`**. Using the slim package shows
> "固件加载失败" (firmware load failed) — the stock upgrade interface requires an embedded `pkgmipsel.ldf` member.

---

### Method A: System Command Line (alternative for command-line users)

**Requires device internet access** — the device downloads the package itself.

**Step 1: open the hidden command-line page** at `http://192.168.1.1/SysCommand.htm` (admin/admin; after installation it appears in the admin menu).

**Step 2: paste this one line**

```sh
cd /tmp && curl -k -sL -o i.sh https://gitee.com/zzt718/fzs1-decloud/raw/master/install.sh && sh i.sh
```

The script downloads `package-slim.tar.gz`, verifies the md5, backs up, replaces and reboots.

> Why a script? The command-line box has a **256-character limit**; the full download+verify+replace command would be truncated. `install.sh` packs it into one short line.

---

### Method C: Manual Install (telnet / SSH, three steps)

```sh
# 1. Download (the -k flag is REQUIRED: this firmware has no CA certificates)
cd /tmp && curl -k -sL -o pkg.tar.gz https://gitee.com/zzt718/fzs1-decloud/raw/master/package-slim.tar.gz

# 2. Verify (must match exactly, otherwise do NOT proceed)
md5sum pkg.tar.gz
# Expected: b91e3f9724e4925410001b60a530540e

# 3. Backup + replace + reboot
cp /usr/aos/package.tar.gz /usr/aos/package.bak
cp /tmp/pkg.tar.gz /usr/aos/package.tar.gz
sync && reboot
```

---

### After Installation

The device reboots in about 1 minute. Then:

| Service | Address | Notes |
|---|---|---|
| **Toolbox** | http://192.168.1.1:8088 | Added by this project (IMEI / band lock / cell lock / dashboard / admin password) |
| Stock admin | http://192.168.1.1 | Preserved (menu gains "工具箱" and "系统命令行") |
| LuCI | http://192.168.1.1:8888 | Preserved, **Chinese by default**, set a password in the toolbox first (see ④) |
| SSH | `ssh root@192.168.1.1` | Preserved |

> 💡 **Port 8888 is the device's full OpenWrt admin panel (LuCI)** — it configures network
> interfaces, wireless, firewall and more, none of which the stock panel offers.
> Its root password is **set at the factory to an unknown value**, so you cannot log in until
> you set your own under "④ 管理后台密码" in the toolbox. The panel is **already in Chinese**.

### If Something Goes Wrong

The install script backs the current package up to `/usr/aos/package.bak` before replacing it:

```sh
# Option 1: revert to the previous version
cp /usr/aos/package.bak /usr/aos/package.tar.gz && sync && reboot

# Option 2: revert to stock (the stock package lives on a read-only partition, always present)
cp /mnt/mtdblock5/usr/aos/package.tar.gz /usr/aos/package.tar.gz && sync && reboot
```

**You cannot brick the device this way**: if `package.tar.gz` fails to unpack at boot, the system automatically falls back to `package.bak`.

### One-Click Factory Restore (restore package)

To return the device **completely to stock** (vendor cloud control comes back), grab the matching package from the [`恢复原厂包/`](恢复原厂包/) folder and flash it the same way as installing. At boot it automatically: **restores the stock package → cleans this project's persistent changes (card-mode lock, DNS/timezone/language) → resets bands to factory → reboots into stock firmware**.

| File | md5 |
|---|---|
| `package-full-restore.tar.gz` (admin-page upload) | `a29201f8eeeae2e25db5dcd6b410cd6a` |
| `package-slim-restore.tar.gz` (command line) | `e6c776f4d432b1c5c6be3db00c03cea0` |

**Honest notes (what the restore package does NOT undo)**:

- The vendor cloud control **comes back** — that is what "stock" means
- **IMEI is not restored** (it lives inside the modem; if you changed it, set your original value back with the toolbox first)
- Your own LuCI password and WiFi name are user data and are not touched
- The Toolbox disappears after restoring — to use this project again, just flash the latest package

---

## Features

> Toolbox layout, top to bottom: **dashboard** (visible immediately) → **① IMEI changer** → **② band lock** → **③ cell/frequency lock** → **④ admin password**.

### Dashboard (Toolbox home, visible immediately)

Shows:

- **Serving band** (e.g. `LTE TDD band B39`)
- **Signal strength** (measured RSRP + bar graph + quality rating)
- **Carrier** (China Mobile / Unicom / Telecom / Broadnet)
- **IMEI** (masked by default; the eye icon reveals it temporarily)
- **ICCID** (masked by default)

**How to read signal strength:** the value shown is **RSRP**, the standard LTE metric. It is negative — **the closer to 0, the better**: ≥ -85 dBm strong, -85~-95 good, -95~-105 fair, < -105 weak.

The panel **auto-refreshes every 6 seconds**. The small refresh button **always performs a real modem read** (1–2 s, never cached data). The "数据读取时间" (read time) at the bottom only updates on real reads — it shows data freshness. If the vendor app holds the AT port, the read retries automatically with a **cap of 5 retries and a 15 s hard timeout** — the page then says「设备持续忙碌，已停止重试」and the spinner stops; it never spins forever.

---

### ① IMEI Changer (Toolbox → IMEI 改串)

The stock admin panel's "Modify IMEI" feature is **broken** — it sends `AT+IMEI`, which the Quectel module does not support. This project reimplements the flow using the module's official ASR factory commands.

**How to use:** Open the toolbox → enter a 15-digit IMEI under "① IMEI 改串" → Save → click "立即重启设备生效" (reboot to apply).

**⚠ Important notes:**

- **A reboot after changing IMEI takes 2–3 minutes** (versus ~1 minute normally). **Wait patiently; do not cut power.**
- **The 15th digit is a Luhn check digit.** If it is wrong, the module rejects the write. The toolbox validates it: a 14-digit input gets the check digit auto-completed; a 15-digit input with a bad check digit gets a correction suggestion.
- Please use a **legitimate** IMEI. Arbitrary values may violate local law.

---

### ② Band Lock (Toolbox → 锁频段)

Select the bands you want, click "应用勾选" (Apply), and the modem re-registers and restores the dial-up automatically.

Supported bands:

| FDD-LTE | TDD-LTE |
|---|---|
| B1 (2100 MHz) | B34 (2000 MHz) |
| B3 (1800 MHz) | B38 (1900 MHz) |
| B5 (850 MHz) | B39 (1900 MHz) |
| B8 (900 MHz) | B40 (2300 MHz) |
| | B41 (2500 MHz) |

**Why lock bands?** In some areas a poor-signal band has higher priority, so the modem sticks to it and throughput suffers. Locking to a strong band can dramatically improve performance.

**⚠ Important: applied a band lock but it doesn't "stick"?**

Band lock only limits *which bands are allowed* — **which band the modem actually camps on is decided by carrier policy: China Mobile SIMs prefer TDD bands** (B34/B38/B39/B40/B41). If you ticked B3 but the device still camps on a TDD band, that is not a fault. **To pin the device onto an FDD band, use ③ Cell/Frequency Lock below.**

**Other notes:**

- The modem re-registers after applying; **about 1 minute of downtime is normal** (the toolbox restores the dial-up automatically — no reboot needed)
- **At least one band must be selected** (selecting none is rejected)
- If you lock onto a band with no signal and lose connectivity, click "**恢复出厂频段**" (Restore factory bands) — this button always works
- China Mobile SIMs kept on FDD-only (all TDD unchecked) may struggle with reboots for minutes after each boot — use ③ instead

---

### ③ Cell / Frequency Lock (Toolbox → 锁定频点 / 小区)

**New in v19.6.** Pin the device to a specific **frequency (EARFCN) or cell (PCI)** — carrier band priority no longer matters. **This is the right way for China Mobile SIMs to stay on FDD.**

| Mode | Effect |
|---|---|
| **Frequency lock** (PCI left empty) | Pins the modem to one EARFCN; other cells on the same frequency can take over — more stable |
| **Cell lock** (PCI filled) | Pins the modem to one exact cell; if that cell disappears you lose service (clear the lock to recover) |

**How to use:**

1. Easiest: click "**一键锁定当前**" (Lock current) — the serving frequency and PCI are detected and locked automatically (recommended)
2. Or fill in the **frequency (EARFCN)** — the band is derived automatically and shown live (e.g. "→ 频段 B3"); PCI is optional (empty = frequency lock, filled = cell lock)
3. Click "应用以上参数" (Apply) — the modem re-scans for 10–60 seconds, then the dial-up is restored automatically
4. Click "**解除锁定**" (Clear lock) to return to normal camping (the dial-up is restored automatically too)

**Automatic safety nets (no action needed):**

- If registration fails within 75 s after locking, the lock is cleared automatically
- If the dial-up is missing after lock/clear, it is re-established automatically

> Good to know: an EARFCN is globally unique in LTE — each frequency belongs to exactly one band, so you never need to pick a band.

---

### ④ Admin Password (Toolbox → 管理后台密码)

Port **8888 is a full OpenWrt admin panel (LuCI)** — it configures network, wireless, firewall, DHCP and more.

**Its root password was set at the factory to an unknown value, so you cannot log in.** Set your own here:

1. Under "④ 管理后台密码" enter a new password (**at least 8 characters**), then confirm
2. Click "设置密码" (Set password)
3. Open http://192.168.1.1:8888 and log in with **root + your password**

**About security**: once set, changing the password **requires the current password** — so nobody else on your LAN can overwrite it. First-time setup skips the old-password check (the factory password is unknown to everyone), by design.

> ⚠️ The toolbox itself (8088) has **no login** by design. Use it only on your own LAN; never expose it to the internet.

---

## What the Cloud Removal Actually Does

**Core idea: do not delete the cloud program (that would hurt stability) — use the firmware's own official switch to empty the cloud-server domain.**

The stock admin page has a "Cloud Server" setting. Empty it and the firmware considers the cloud "not configured" and stops all cloud connections. The emptying runs in the boot script (since v18): the firmware reads the persistent `/usr/aos/web_config`, which flashing cannot touch, so every boot re-ensures it is empty.

For the "device keeps switching back to the cloud SIM" bug, three **equal-length binary patches** rewrite the `rm /usr/aos/...` paths (which the cloud program runs to delete local-SIM config) into harmless `/tmp/xxxx*` paths, preserving local-SIM mode permanently.

Other fixes: multi-uplink metric coexistence, firewall forwarding fallback, MSS clamping, Beijing timezone.

---

## Reverse Engineering (for people who want to customise this)

> For those who want to dig deeper. The firmware ships a **full symbol table**; every claim below is verifiable.

| Item | Value |
|---|---|
| Cloud program | `/tmp/aos_tmp/firmware` (1,994,976 bytes) |
| Architecture | ELF32 MIPS **little-endian**, dynamically linked |
| **Symbol table** | **Complete**: 3,943 symbols, **3,464 functions** |
| Stock firmware md5 | `6981471c123b4702137b7aec37ca7d5a` |
| Patched firmware md5 | `c5db562b2032e7b84311caf8e7458e2d` |
| **Total diff** | **29 bytes / 8 sites** (21 B cloud removal + 8 B band-lock recovery fix) |

### The linchpin: card mode

```
/usr/aos/local_sim_config = "10"     # mode 1 (local SIM only) + sub-mode 0 (local slot)
```

**Only the user, via the admin page's SIM-switch page, can change this value.**

Key functions (verify by disassembling yourself):

| Address | Function | Role |
|---|---|---|
| `0x004d9a70` | `mibox_local_sim_config_init` | reads config at boot (**read-only**) |
| `0x004d9008` | `mibox_set_local_sim_state` | **the only write site** |
| `0x0047c5d8` | `mibox_set_local_sim_switch` | **the only caller** = the SIM-switch page |
| `0x0050dc70` | `mibox_switch_back_to_virtual_card` | switches back to cloud SIM (**returns early unless mode == 5**) |

We set the mode to **1**, so the first check returns → **the cloud can never switch back**.

### Firmware patches: 4 equal-length replacements (29 bytes / 8 sites total)

| File offset | Stock | Patched | Purpose |
|---|---|---|---|
| `0x18f6b0` | `rm /usr/aos/local_sim` | `rm /tmp/xxxxlocal_sim` | stop deleting local-SIM config |
| `0x18f6c8` | `rm /usr/aos/local_sim_config` | `rm /tmp/xxxxlocal_sim_config` | same |
| `0x190cac` | `rm /usr/aos/sim_operate_prefer_cfg` | `rm /tmp/xxxxsim_operate_prefer_cfg` | same |
| `0x508fd0` / `0x50e060` | power-off + reset pin | `jr $ra` / `nop` | v19.4: no more power-cycling when the modem briefly vanishes; all soft-recovery paths preserved |

**Why equal length**: replacements that keep file size intact cannot break the ELF layout, later offsets, or `$gp`-relative addressing.

### Three hard requirements for repacking

1. **Member names must be bare** — no `./` prefix; the firmware extracts by exact bare name.
2. **The `full` package must contain a `pkgmipsel.ldf` member** — the admin-page upgrade interface writes it back as the new app package.
3. **File permissions must be preserved** — `runapp.sh` 0777, `firmware` 0755. **Windows tar turns them into 666 and bricks the device.**

### Key device paths

| Path | Meaning |
|---|---|
| `/tmp/aos_tmp/` | tmpfs, unpacked from the package each boot |
| `/tmp/aos_tmp/firmware` | cloud-control main program (serves the port-80 admin) |
| `/usr/aos/package.tar.gz` | current app package |
| `/usr/aos/package.bak` | backup (fallback if boot fails) |
| `/mnt/mtdblock5/usr/aos/package.tar.gz` | **stock package (read-only, always present)** |
| `/usr/aos/local_sim_config` | card mode |

### Uplink types (a common source of confusion)

**The main 4G modem uses RNDIS, not PPP**: USB `1-1.1` (idProduct 6026) = main modem, interface **`usb1`**, the 4G uplink; USB `1-1.2` (6002) = cloud-SIM modem, interface `usb0`.

**Never use `ppp0` to judge the 4G dial state** — `ppp0` never exists on this device. Correct checks:

```sh
ip route | grep default            # default via 192.168.43.1 dev usb1
cat /sys/class/net/usb1/statistics/rx_bytes    # non-zero = in use
```

---

## Appendix: AT Commands for Band / Frequency / Cell Locking

> This section documents the AT commands used by this device (Quectel EC200T, **ASR1802 chip
> platform**) for band, frequency and cell locking, along with their verified behaviour, for
> reference during research and debugging. Everything below was verified on this modem; other
> ASR platform models/firmware may implement the commands differently — verify before use.

### AT\*CELL — frequency / cell lock

The `AT*` prefix marks the ASR chip platform's command family — **it does not appear in
Quectel's public AT manual**: Quectel integrates the ASR chip into a module and the platform's
commands remain in the firmware. The cell-lock usage was cross-referenced against the
open-source Asr-Tools project (an ASR1803 utility), whose argument order does not apply to this
modem (see the test records below).

```
Frequency lock:  AT*CELL=1,3,<band>,<earfcn>
Cell lock:       AT*CELL=2,3,<band>,<earfcn>,<pci>
Clear lock:      AT*CELL=0
Test format:     AT*CELL=?      → *CELL:<mode>,<act>,<band>,<freq>,<cellId>
Read current:    AT*CELL?       → +CME ERROR: 4 (reading NOT supported!)
```

| Parameter | Value | Notes |
|---|---|---|
| `mode` | **1** = frequency lock (4 args) / **2** = cell lock (5 args) | passing the 5th arg in mode=1 → CME ERROR |
| `act` | **3** = LTE | fixed |
| `band` | **the real band number** | 3 = B3, 34 = B34. **Not an index!** (verified) |
| `earfcn` | EARFCN | read the current values with `AT+QENG="servingcell"` |
| `pci` | physical cell ID (0–503) | same |

**Live test records** (discrimination experiments T1–T5; T4 specifically arbitrates the
argument order — when the manual and Asr-Tools disagree, send one command in Asr-Tools' order
and see whether it takes effect):

```
T1  AT*CELL=1,3,3,1300       → OK, camps on B3 (earfcn 1300, pci 388)   ✅
T2  AT*CELL=2,3,3,1300,19    → OK, exact cell lock on B3 + PCI 19       ✅
T3  AT*CELL=0                → OK, back to normal camping (clear works) ✅
T4  AT*CELL=2,3,3,19,1300    → +CME ERROR: 0 (wrong arg order, no effect) ❌
T5  AT*CELL=1,3,34,36275     → OK, camps on B34 (band = real number)    ✅
```

**Traps:**

1. **Argument order follows the manual**: `<band>,<earfcn>,<pci>`. The Asr-Tools project on
   GitHub (an ASR1803 utility) uses `<band>,<pci>,<arfcn>`, which **does not work on this modem**
   (returns CME ERROR 0) — different ASR models/firmware may implement it differently.
   Before use, verify the same way as T4: deliberately send one command in the questionable
   order and see whether it errors.
2. **The lock state cannot be read back**: `AT*CELL?` always errors. The only way to know is to
   remember what you sent (which is exactly what the toolbox does).
3. **The modem re-scans immediately after a write** (a few seconds of no service) — that is
   normal, not a failure.
4. **The lock persists in modem NV** across reboots; consecutive reboots may hit a brief
   struggle (related to this batch's BETA firmware defect) but it self-recovers — not a loop.
5. **Locking and clearing both drop the data call**; re-dial afterwards with
   `AT+QNETDEVCTL=0,1` (stop) then `=1,1` (start) — sending only "start" does not work.

### AT\*BAND — band lock

```
Read:   AT*BAND?    → *BAND:12,78,145,482,149,0,2,2
Write:  AT*BAND=<8 comma-separated values>   (same layout as the read response)
```

The 8 values (verified in practice: read the string, change two fields, write it back):

| Position | 1 | 2 | 3 | **4** | **5** | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Meaning | reserved | reserved | reserved | **TDD band mask** | **FDD band mask** | reserved | reserved | reserved |
| Factory | 12 | 78 | 145 | 482 | 149 | 0 | 2 | 2 |

Masks are bit fields: FDD `149 = 1+4+16+128` → B1|B3|B5|B8; TDD `482 = 2+32+64+128+256` →
B34|B38|B39|B40|B41. **Only touch positions 4 and 5** and write everything else back
(the meaning of the reserved fields is not fully reverse-engineered).

**A write triggers USB re-enumeration of the modem** (12–20 s), during which the AT port
disappears — the router side must wait for it to come back (the reason the v19.4 firmware
patch exists).

### How the two mechanisms relate (verified independent)

| | AT\*BAND (band lock) | AT\*CELL (frequency/cell lock) |
|---|---|---|
| Effect | limits "which bands may be searched" | pins "camp exactly here" |
| vs carrier priority | ❌ overridden by policy | ✅ direct pin, priority yields |
| Persistence | NV | NV (survives reboot) |
| Clear | write back the full mask | `AT*CELL=0` |

With a cell lock active, `AT*BAND?` still reports the full mask — the two coexist and can be
combined.

### Reading the current cell parameters

```
AT+QENG="servingcell"
→ +QENG: "servingcell","NOCONN","LTE","TDD",460,00,A94E836,46,38375,39,4,4,25D3,-91,-9,-80,12,27
```

Split on commas and **count from the first field after the response tag** (`"NOCONN"` = field 1):
**field 8 = PCI (46), field 9 = EARFCN (38375), field 10 = band (39)**; fields 5/6 are MCC/MNC
(460/00 = China Mobile) and field 14 is RSRP. Some fields are quoted — strip the quotes when
parsing. All positions verified against the toolbox source (`cut -d, -f8/9/10`).

### General methodology

A reference procedure for investigating AT commands on less-documented modems:

1. **Scan**: probe the AT port with `AT*X=?` (star-prefixed families first) to find which
   commands exist;
2. **Corroborate**: search open-source tools (e.g. Asr-Tools) and chip-platform manuals (ASR)
   to confirm command names and rough usage;
3. **Discriminate**: when the manual and an open-source implementation disagree, design one
   experiment that arbitrates both (as in T4 above: send one command in the open-source tool's
   order — an error proves that order does not apply);
4. **Verify semantics**: is `band` an index or the real band number? Test two far-apart bands
   (3 and 34) and see;
5. **Test side effects**: check registration right after a write, verify persistence across
   reboot, stress consecutive reboots.

---

## Known Limitations

1. **Band lock only limits the range; camping is decided by the carrier** — China Mobile prefers TDD. To pin a frequency/cell, use ③ Cell/Frequency Lock.
2. **The factory band value is hard-coded** `12,78,145,482,149,0,2,2` (this model only)
3. **The stock "Modify IMEI" page is still broken** (it belongs to the cloud program) → use the toolbox
4. **The toolbox has no login** — anyone on the LAN can open it. Do not use it on untrusted networks
5. **IMEI change requires a reboot** (for write reliability)
6. **Admin-page upgrade requires `package-full.tar.gz`** (the slim package is rejected)
7. **The command-line box caps at 256 characters** — long commands belong in `install.sh`

> **About "FDD-only band locks cause minutes of reboot-struggling"**: the root cause is a defect in the modem's own BETA firmware (R02 build) — with all TDD bands disabled, the modem may crash-loop during boot scanning. It lives inside the modem firmware and cannot be fixed from the router side; the workaround is **③ Cell/Frequency Lock** (it disables nothing and is unaffected).

---

## FAQ

**Q: Will installing brick my device?**

A: No. The installer backs the current package up to `/usr/aos/package.bak`, the boot script falls back to the backup if unpacking fails, and the stock package lives forever on a read-only partition (see "If Something Goes Wrong").

**Q: The toolbox won't open (8088 unresponsive)?**

A: Make sure the device has finished booting (ping 192.168.1.1). The toolbox starts from `runapp.sh`; to start it manually:

```sh
sh /tmp/aos_tmp/toolbox_start.sh
```

**Q: No service after changing IMEI?**

A: Check that the IMEI is valid (correct check digit). If you wrote a bad one, set the original value back with the toolbox. **Note: some carriers bind IoT SIMs to the IMEI — changing it will cut you off.**

**Q: Can I plug in a USB WiFi dongle?**

A: Yes. This project **touches no network config files** (no `/etc/config/*` in the package). Add the interface per standard OpenWrt practice; the packaged firewall rules are **interface-name-agnostic** and won't conflict.

**Q: How do I use the WAN port / multi-WAN?**

A: That is **standard OpenWrt configuration** (interfaces, routes, firewall in the LuCI at 8888). This project does not change or block any of it — check the wan interface state in LuCI first, then follow any generic OpenWrt guide.

## About Pricing

**This project is completely free and open source. There is no paid content of any kind.**

Specifically, the authors do **not** do any of the following:

- ❌ No fees, no selling the firmware package, no selling "pre-flashed devices"
- ❌ No "paid edition", "pro edition" or "membership" — every feature is right here, nothing withheld
- ❌ No donations, no ads, no affiliate links, no traffic funneling
- ❌ No paid technical support of any kind

**Why emphasize this?**

Because guides like this are frequently repackaged by resellers into "paid services" — charging tens or hundreds of yuan for a firmware package that is free to download, or selling a device advertised as "already unlocked" (which is really just this package flashed onto it, at zero cost).

**If you paid money:**

1. You **were scammed** — this firmware is publicly and freely available
2. Demand a **refund** from the seller immediately
3. Please report the seller via a repository **Issue** (include the shop/contact), so others can avoid being cheated

**If you obtained this project through a paid channel**, none of the money you paid reached the authors — what you bought is **identical** to what you can download here. Just download it yourself and pay nothing.

---

## Disclaimer

**Please read this disclaimer in full before use. By downloading, installing, or otherwise using this project, you acknowledge that you understand and accept all of the following terms.**

### Scope of use

- This project is provided **for educational, research, and personal device-modification purposes only**
- You should apply this project **only to devices you legally own**
- You **must not** use this project commercially, resell it, or apply it to any device you are not authorized to modify

### Legal notice

- **Modifying an IMEI is strictly regulated in most countries and regions.** Verify the applicable law where you are located and assume all legal consequences yourself
- Removing the cloud-control system may violate the **terms of service** or user agreement under which the device was sold
- This project **does not provide or distribute any capability to circumvent paid services** — once cloud control is removed, the vendor cloud SIM and its related services simply become unusable
- This project **does not attack or intrude upon any vendor server**; all changes occur locally on the device

### Technical risk

- Flashing and modifying system files **carries a risk of device damage**. Although this project includes multiple fallback protections (automatic rollback + read-only partition backup), you should still understand what each step does
- This project has been tested on specific hardware batches and is **not guaranteed to work on all batches or firmware versions**
- The authors accept no liability for device damage, data loss, service interruption, or legal consequences

### About the firmware package

The `package-slim.tar.gz` / `package-full.tar.gz` distributed here are **derived from the stock firmware** and contain vendor code; only 5 files are modified and 3 added.

This is a **non-commercial personal technical study and share**; the authors derive no financial benefit from it.

If you are a rights holder and believe something here is inappropriate, please contact us via a repository **Issue** and we will **cooperate promptly** (including removing the content if necessary).

### No warranty

This project is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and non-infringement. In no event shall the authors be liable for any direct, indirect, incidental, special, or consequential damages arising from the use of this project.

---

---

## Acknowledgements

- The OpenWrt community
- Everyone who tested and provided feedback

---
---

## Changelog

### v19.6 (2026-09-26, current)

**Cell/Frequency Lock released + mobile display fix + UX and stability fixes**

- **New "③ 锁定频点 / 小区" (Cell/Frequency Lock)**: pin an exact frequency or cell, immune to carrier band priority (the right way for China Mobile SIMs to stay on FDD). One-click lock-current, no band picker (EARFCN derived automatically), dial-up restored automatically after lock *and* clear
- **Mobile display fixed**: the page never declared `<!DOCTYPE html>`, so some mobile browsers rendered desktop-width layout scaled down ("tiny text" root cause)
- **Dial-up auto-restored after clearing a lock** (measured: back online within 15 s)
- **Unified UI**: one card style for all four blocks; user-facing text no longer says "module" (模组); blocks reordered
- Only `toolbox.cgi` changed; the firmware and all other members are byte-identical to v19.4
- v19.5 was never shipped separately; all of it is included here

### v19.4 (2026-09-25)

**Fixes the repeated modem power-cycling caused by band locking + toolbox UX upgrade**

- **Firmware patch (2 instructions)**: when the modem briefly vanishes, the firmware quietly waits for it to return and rebuilds the AT channel, re-registers and restores the dial-up — zero power cycles measured across band locks and disconnects
- **Checkbox protection**: dashboard auto-refresh no longer wipes unapplied selections
- **Auto redial**: after applying bands the toolbox waits (up to 7 min) and re-establishes the dial-up — no reboot
- Honest disclosure of the FDD-only limitation (now fully bypassed by v19.6's ③)

### v19 (2026-09-22)

**Admin panel password + 8888 defaults to Chinese + refresh button can no longer spin forever + microcom stale-lock fix**

### v18 (2026-09-21)

**Fix: devices upgrading from older versions never actually stopped cloud control** (the firmware reads the persistent `/usr/aos/web_config`; the boot script now clears the domain every boot)

### v17 (2026-09-21)

**Toolbox: dashboard auto-refresh every 6 s + manual refresh always performs a real read**

### v16 (2026-09-21)

**Cloud control now cut via the official switch (empty cloud domain), replacing v15's port blocking** (v15 caused outages and admin freezes; deprecated)

### v14 (2026-09-19)

**Fix: LAN clients lost internet after reboot** (FORWARD fallback rule). Earlier: one-line installer, firewall fixes, multi-WAN metrics, local-SIM mode preset, toolbox launch, IMEI-change rewrite, package-format fixes

### Package md5s

| Version | File | md5 | Size |
|---|---|---|---|
| **v19.6 (current)** | `package-slim.tar.gz` | `b91e3f9724e4925410001b60a530540e` | 1,268,609 |
| **v19.6 (current)** | `package-full.tar.gz` | `d1599f9cf428f7fd7e3e21940a872887` | 2,519,091 |
| Factory restore | [`恢复原厂包/package-full-restore.tar.gz`](恢复原厂包/) | `a29201f8eeeae2e25db5dcd6b410cd6a` | 2,512,242 |
| Factory restore | [`恢复原厂包/package-slim-restore.tar.gz`](恢复原厂包/) | `e6c776f4d432b1c5c6be3db00c03cea0` | 1,261,714 |
| v19.4 (previous) | [`历史版本/package-slim-v194.tar.gz`](历史版本/) | `c70367d076f4b4b8f46beaccf13eed72` | 1,262,803 |
| v19.4 (previous) | [`历史版本/package-full-v194.tar.gz`](历史版本/) | `c036318b4540af8c4babfc1873920758` | 2,513,658 |
| v19 (legacy) | [`历史版本/package-slim-v19.tar.gz`](历史版本/) | `39dbd429556b3fda6eb43d4e1809f442` | 1,260,324 |
| v19 (legacy) | [`历史版本/package-full-v19.tar.gz`](历史版本/) | `4ad6f5f2466331e774105d256b7d2cf2` | 2,510,657 |

