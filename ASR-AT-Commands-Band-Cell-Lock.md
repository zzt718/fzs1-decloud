# ASR Platform LTE Modem AT Commands: Band Lock / Frequency Lock / Cell Lock

> **Platform**: ASR chipset (ASR Microelectronics) LTE modules
> **Verified on**: Quectel EC200T (ASR1802, firmware `EC200TCNHAR02A01M16_BETA0520_PS`)
> **Commands covered**: `AT*BAND` (band lock), `AT*CELL` (frequency / cell lock),
> `AT+QENG="servingcell"` (read current cell parameters)
> **Source**: field notes from the 蜂助手 S1 (MIBOX-668M2) de-cloud project, published as a
> standalone document for easier search and citation.
> Other ASR models / firmware may implement these commands differently — verify before use
> (see "Investigation methodology" at the end).

---

## Related models and search keywords

| Category | Terms |
|---|---|
| Chip platform | ASR1802, ASR1803, ASR chipset, ASR Microelectronics |
| Modules | Quectel EC200T, EC200N, EC200A (same platform, may apply) |
| Commands | `AT*BAND`, `AT*CELL`, `AT+QENG="servingcell"`, `AT+QNETDEVCTL` |
| Features | band lock (band-lock), frequency lock (frequency-lock), cell lock (cell-lock), EARFCN, PCI, LTE band |
| Devices | 蜂助手 S1, MIBOX-668M2, MT7628 4G CPE |

---

## 1. Background

LTE modules camp on cells according to carrier network policy. Two common needs arise:

1. **Band lock** — restrict which bands the module may search (avoid a poor-signal band with
   high priority);
2. **Frequency / cell lock** — pin the module to a specific EARFCN or PCI cell, immune to
   carrier priority.

`AT*BAND` covers (1) by limiting the search range; `AT*CELL` covers (2) by direct assignment.
They are independent and can be combined.

---

## 2. `AT*CELL` — frequency / cell lock

The `AT*` prefix marks the ASR chipset's command family — **it does not appear in Quectel's
public AT manual**: Quectel integrates the ASR chip into a module and the platform's commands
remain in the firmware. The cell-lock usage was cross-referenced against the open-source
Asr-Tools project (an ASR1803 utility), whose argument order does not apply to this modem
(see the test records in section 5).

### 2.1 Syntax

```
Frequency lock:  AT*CELL=1,3,<band>,<earfcn>
Cell lock:       AT*CELL=2,3,<band>,<earfcn>,<pci>
Clear lock:      AT*CELL=0
Test format:     AT*CELL=?      → *CELL:<mode>,<act>,<band>,<freq>,<cellId>
Read current:    AT*CELL?       → +CME ERROR: 4 (reading not supported)
```

### 2.2 Parameters

| Parameter | Value | Notes |
|---|---|---|
| `mode` | **1** = frequency lock (4 args) / **2** = cell lock (5 args) | 5th arg with mode=1 → CME ERROR |
| `act` | **3** = LTE | fixed |
| `band` | **the real band number** | 3 = B3, 34 = B34. **Not an index** (verified) |
| `earfcn` | EARFCN | read with `AT+QENG="servingcell"` |
| `pci` | physical cell ID (0–503) | same |

### 2.3 Behaviour

- The lock is written to modem **NV** and survives reboots;
- The modem **re-scans immediately** after a write (a few seconds to tens of seconds with no
  service) — normal;
- Locking and clearing both **drop the data call**; re-dial with `AT+QNETDEVCTL=0,1` (stop)
  then `=1,1` (start) — sending only "start" does not work (the modem's call state lags the
  queried value);
- The lock state **cannot be read back**; keep your own record.

---

## 3. `AT*BAND` — band lock

### 3.1 Syntax

```
Read:   AT*BAND?    → *BAND:12,78,145,482,149,0,2,2
Write:  AT*BAND=<8 comma-separated values>   (same layout as the read response)
```

### 3.2 The 8 values

In practice: read the current string, change two positions, write it back.

| Position | 1 | 2 | 3 | **4** | **5** | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Meaning | reserved | reserved | reserved | **TDD band mask** | **FDD band mask** | reserved | reserved | reserved |
| Factory | 12 | 78 | 145 | 482 | 149 | 0 | 2 | 2 |

Masks are bit fields:

- FDD `149 = 1+4+16+128` → B1 | B3 | B5 | B8
- TDD `482 = 2+32+64+128+256` → B34 | B38 | B39 | B40 | B41

**Only modify positions 4 and 5** and write the rest back unchanged (the reserved fields are not
fully reverse-engineered).

### 3.3 Behaviour

A write triggers **USB re-enumeration** of the modem (12–20 s), during which the AT port
disappears and the host must wait for it to return. This is modem behaviour, independent of the
command chosen (`AT*BAND` and `AT+QCFG="band"` are equivalent).

---

## 4. Reading the current cell: `AT+QENG="servingcell"`

```
AT+QENG="servingcell"
→ +QENG: "servingcell","NOCONN","LTE","TDD",460,00,A94E836,46,38375,39,4,4,25D3,-91,-9,-80,12,27
```

Split on commas and **count from the first field after the response tag** (`"NOCONN"` = field 1):

| Field | Meaning | Example |
|---|---|---|
| 4 | duplex mode (FDD / TDD) | TDD |
| 5 / 6 | MCC / MNC | 460 / 00 (China Mobile) |
| **8** | **PCI** | 46 |
| **9** | **EARFCN** | 38375 |
| **10** | **band** | 39 |
| 14 | RSRP | -91 |

Some fields are quoted — strip the quotes when parsing.

---

## 5. Live test records (discrimination experiments T1–T5)

T4 specifically arbitrates the argument order: when the manual and Asr-Tools disagree, send one
command in Asr-Tools' order and see whether it takes effect.

```
T1  AT*CELL=1,3,3,1300       → OK, camps on B3 (earfcn 1300, pci 388)      ✅
T2  AT*CELL=2,3,3,1300,19    → OK, exact cell lock on B3 + PCI 19          ✅
T3  AT*CELL=0                → OK, back to normal camping (clear works)    ✅
T4  AT*CELL=2,3,3,19,1300    → +CME ERROR: 0 (wrong arg order, no effect)  ❌
T5  AT*CELL=1,3,34,36275     → OK, camps on B34 (band = real number)       ✅
```

---

## 6. Known traps

1. **Argument order follows the manual**: `<band>,<earfcn>,<pci>`. The Asr-Tools project on
   GitHub (an ASR1803 utility) uses `<band>,<pci>,<arfcn>`, which **does not work on this
   modem** (returns CME ERROR 0) — different ASR models/firmware may implement it differently.
   Before use, verify the same way as T4: deliberately send one command in the questionable
   order and see whether it errors;
2. **The lock state cannot be read back**: `AT*CELL?` always errors; keep your own record;
3. **A brief loss of service after a write** is normal (the modem is re-scanning);
4. **Consecutive reboots while locked**: this batch of modem firmware (a BETA build) has a
   defect — with all TDD bands disabled, consecutive reboots may hit a brief struggle that
   self-recovers; avoid back-to-back reboots while locked;
5. **Re-dial after lock/clear** (see 2.3).

---

## 7. Investigation methodology

A reference procedure for investigating AT commands on less-documented modems:

1. **Scan**: probe the AT port with `AT*X=?` (star-prefixed families first) to find which
   commands exist;
2. **Corroborate**: search open-source tools (e.g. Asr-Tools) and chip-platform manuals (ASR)
   to confirm command names and rough usage;
3. **Discriminate**: when the manual and an open-source implementation disagree, design one
   experiment that arbitrates both (as in T4 above: send one command in the open-source tool's
   order — an error proves that order does not apply);
4. **Verify semantics**: is `band` an index or the real band number? Test two far-apart bands
   (3 and 34);
5. **Test side effects**: check registration right after a write, verify persistence across
   reboot, stress consecutive reboots.

---

## 8. Related resources

- Open-source reference: [Asr-Tools](https://github.com/huwangkeji/Asr-Tools) (ASR1803 utility,
  Web Serial based)
- This project: [蜂助手 S1 de-cloud project](README_EN.md) (full device modification, toolbox
  and reverse-engineering notes)
- Chinese version: [ASR平台AT命令-锁频段锁频点锁小区.md](ASR平台AT命令-锁频段锁频点锁小区.md)

---

> Every conclusion here was verified on real hardware. Other ASR platform models / firmware may
> behave differently — verify before applying to other devices.
