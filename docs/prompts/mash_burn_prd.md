# Product Requirements Document: *Mash & Burn* (Working Title)
**Subtitle:** Hyper-Realistic Ray-Traced Homebrewing, PVP Deathmatch & Arson Fraud Simulator  
**Original Pitch By:** Eric Wika, Mike Dunham & Robert Peckham (April 2021)  
**Target Build Environment:** Beluga Multi-Agent Orchestrator (`beluga-labs/beluga`) — Parallel Git Worktree Execution  

---

## 1. Executive Summary & Vision
*Mash & Burn* is a hyper-realistic, physics- and chemistry-driven homebrewing simulator built for high-end console/PC hardware (PS5 target spec with full ray tracing) that escalates a cozy garage brewing hobby into high-stakes competitive chaos. Players manage exact mash temperatures, alpha-acid hop isomerization, yeast attenuation, and keg carbonation—while simultaneously surviving live PVP brewery deathmatches, dodging property-damage investigations after "accidental" propane boil-over house fires, enduring real-world social media bot campaigns when taste-testers hate their beer, and optionally piping live telemetry to a physical countertop robotic brewing rig.

---

## 2. Multi-Agent Worktree Architecture (For Beluga Execution)
To maximize parallel execution across Beluga worktrees and P2P Friends nodes, the codebase is partitioned into five strictly decoupled modules with defined API contracts:

| Worktree / Module | Owner Role / Agent Scope | Core Responsibility |
| :--- | :--- | :--- |
| `wt/chem-engine` | Core Simulation Agent | Deterministic thermodynamics, enzymatic mash conversion, hop IBU curves, yeast fermentation kinetics, and off-flavor chemistry. |
| `wt/render-raytracing` | Graphics & VFX Agent | Ray-traced fluid caustics (wort/beer translucency, SRM color refraction), volumetric steam, foam head physics, and dynamic fire/smoke propagation. |
| `wt/pvp-arson` | Gameplay & Combat Agent | 4-player brewery deathmatch mechanics, improvised brewing-equipment weapons, propane/burner sabotage, and insurance adjuster AI / fraud mini-games. |
| `wt/social-psyops` | External Integration Agent | Webhook/API bridge for automated social media bot swarm triggers, sentiment scoring, and generated smear posts. |
| `wt/hardware-bridge` | Robotics / IoT Agent | Local WebSocket/Serial daemon translating in-game actuator states into G-code / MQTT commands for physical PID controllers, peristaltic pumps, and robotic arms. |

---

## 3. Core Functional Requirements

### 3.1 Hyper-Realistic Brewing & Chemistry Engine (`wt/chem-engine`)
* **Water Chemistry & Mash Profile:**
  * Track real-time ion concentrations ($\text{Ca}^{2+}$, $\text{Mg}^{2+}$, $\text{SO}_4^{2-}$, $\text{Cl}^-$, $\text{HCO}_3^-$) and mash $\text{pH}$ ($5.2\text{–}5.6$ target window).
  * Model $\alpha$- and $\beta$-amylase enzymatic conversion curves across temperature rests ($144^\circ\text{F}\text{–}162^\circ\text{F}$). Scorching the grain bed produces quantifiable astringency and DMS/phenolic off-flavors.
* **Boil, Hop Utilization & Cooling:**
  * Implement Tinseth IBU utilization formulas sensitive to wort specific gravity ($OG$) and boil vigor.
  * Track hop oil volatilization by addition timing (bittering, flavor, whirlpool/flameout).
  * Rapid cooling via immersion/plate chillers; slow cooling increases infection vector probability (*Lactobacillus*, *Pediococcus*, *Brettanomyces*).
* **Fermentation & Packaging:**
  * Strain-specific yeast attenuation, flocculation, and ester/fusel alcohol generation driven by ambient fermentation chamber temperature.
  * Force carbonation via $\text{CO}_2$ regulator PSI + temperature charts (volumes of $\text{CO}_2$), or bottle conditioning with priming sugar calculations (over-priming creates pressurized glass "bottle bombs").

### 3.2 Ray-Traced Visuals & Fluid Physics (`wt/render-raytracing`)
* **Spectral Beer Rendering:** Ray-traced light absorption and scattering calibrated to exact Standard Reference Method ($\text{SRM } 2\text{–}40+$) color values and turbidity/haze metrics (NEIPA vs. filtered Pilsner).
* **Subsurface Foam & Nucleation:** Micro-bubble nucleation streams rising from laser-etched glass bottoms, dynamically sustaining head retention based on protein and iso-alpha-acid levels.
* **Thermal & Fire Simulation:** Volumetric steam condensation on garage windows, boil-over foam expansion physics, and real-time ray-traced reflections off stainless steel kettles and burning drywall.

### 3.3 PVP Deathmatch & House-Fire Insurance Fraud (`wt/pvp-arson`)
* **Brewery Deathmatch Mode (2–8 Players):**
  * Players race to brew a judge-specified style within a 15-minute round while sabotaging rival bays.
  * **Improvised Arsenal:** High-pressure sanitizing wands (blinding/slippery floors), scalding wort ladles, shattered hydrometer shivs, over-pressurized corny kegs (usable as concussive rockets), and exploding over-primed bottle-bomb grenades.
  * **Sabotage Mechanics:** Cutting a rival's immersion chiller hose, dumping lacto-infected starter into their fermenter, or cranking their propane regulator past redline.
* **House-Fire & Insurance Fraud Loop:**
  * **Ignition Triggers:** Unattended boil-overs hitting open propane flames, frayed extension cords near spilled star-san/water, or intentional grease/grain-dust accelerant placement when a batch is ruined beyond salvage.
  * **The Fraud Mini-Game:** Once a fire starts, players have a 45-second **"Staging Window"** before the fire department arrives to plant tampered receipts, hide intact equipment in the trunk of a Buick outside, and stage plausible accidental ignition evidence while escaping smoke inhalation.
  * **Adjuster Interrogation & Payout:** An AI Insurance Claims Adjuster inspects thermal burn patterns, gas valve states, and player heart-rate/sweat tells. Passing the audit pays out **150% replacement capital** to upgrade to a commercial-grade electric brewhouse; failing triggers criminal arson penalties and bankruptcy.

### 3.4 Real-World Social Media Bot Harassment Engine (`wt/social-psyops`)
* **Tasting & Review Trigger:** At the end of every batch, an AI Beer Judge panel (and rival PVP players) scores the beer on aroma, appearance, flavor, mouthfeel, and style accuracy.
* **Bot Swarm Dispatch (Sandbox & Live Webhook Modes):**
  * If a batch scores below **45/100** (or triggers severe off-flavors like diacetyl/butter-bomb or acetaldehyde/green apple), the game's `SocialPsyopsService` dispatches a structured payload containing the player's configured handle, beer name, and tasting flaws.
  * **Safe-Default Sandbox Feed:** Built-in simulated social feed ("HopX / Untappd-Parody") flooded by 500+ procedural bot accounts roasting the player's sanitation habits, tagging local health inspectors, and posting deepfake photos of their infected carboy.
  * **Opt-In Live Webhook Bridge:** Configurable local webhook endpoint (`POST /api/v1/psyops/roast`) allowing players/friend groups to route roast alerts directly into a dedicated Discord/Google Chat channel or opt-in burner social accounts via authenticated API tokens (strictly gated behind explicit local `.env` consent and rate-limiters).

### 3.5 Physical Robotic Brewing Mirror (`wt/hardware-bridge`)
* **Hardware Abstraction Layer (HAL):** Decoupled local daemon (`beluga-brew-bridge`) communicating over Serial/USB, MQTT, or WebSockets so the game runs seamlessly with or without physical hardware connected.
* **Telemetry & Command Protocol (JSON over WebSocket):**
  * Streams real-time state frames at $10\text{ Hz}$:
    ```json
    {
      "step": "MASH_IN",
      "target_temp_c": 66.7,
      "pump_duty": 0.85,
      "valve_states": [1, 0, 1],
      "hop_drop_hopper": 2
    }
    ```
* **Supported Physical Actuators:**
  * **Tier 1 (DIY Smart Rig):** PID heating element relays, DS18B20 temperature probes, 12V peristaltic dosing pumps (for water salts/lactic acid), and servo-actuated hop droppers.
  * **Tier 2 (6-Axis Cobot Arm):** Inverse-kinematics waypoint planner for stirring the mash tun, lifting the grain basket for sparging, and pitching yeast vials.
* **Hardware Safety Interlocks (Mandatory):**
  * Physical E-Stop kill switch override, hard firmware thermal cutoff ($102^\circ\text{C}$ dry-fire protection), and automatic disconnect when the in-game player triggers **House-Fire Insurance Fraud** mode (so the robot does *not* mirror arson in your actual kitchen).

---

## 4. Technical Stack & Milestones for Beluga Agents

* **Engine & Graphics:** Unreal Engine 5.4+ (C++ core modules + Lumen/Hardware Ray Tracing + Niagara fluid/fire VFX) or Godot 4.3+ (for rapid PC/Linux prototyping prior to PS5 dev-kit porting).
* **Local Companion Services:** Rust or Python FastAPI microservice handling the `wt/hardware-bridge` serial/MQTT loop and `wt/social-psyops` webhook dispatcher.
* **Milestone 1 (Weekend Vertical Slice):** `wt/chem-engine` deterministic mash/boil/ferment math + basic 3D garage kitchen + simulated social media roast feed.
* **Milestone 2 (PVP & Arson):** Multiplayer lobby, keg/bottle-bomb combat physics, propane fire spread, and the 45-second Insurance Fraud staging mini-game.
* **Milestone 3 (Ray Tracing & Hardware HAL):** Full SRM spectral beer shader, volumetric steam, and mock/real MQTT output for PID temperature controllers and servo hop droppers.