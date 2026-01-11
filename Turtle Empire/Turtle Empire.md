# PROJECT: HIVE MIND (ATM10)

**Architecture:** Hierarchical C2 (Command & Control) with Autonomous Agents
**Network Topology:** Star-of-Stars (Base -> Managers -> Workers)

## 1. System Architecture

### Tier 1: The Base (Strategic)

* **Hardware:** Advanced Computer, Large Monitor, Ender Modem.
* **Role:** The "Database" and "Dashboard."
* **Responsibilities:**
* Holds the "Master State" of the entire empire.
* Displays aggregate stats (Total Resources, Fuel Levels, Active Drone Count).
* Hosts the "Firmware Repository" for code updates.


* **Logic:** Passive Listener. It never commands a turtle directly. It only aggregates data from Managers.

### Tier 2: The Managers (Tactical)

* **Hardware:** Advanced Computer, Ender Modem.
* **Role:** The "Squadron Leader."
* **Responsibilities:**
* Manages a specific industry (e.g., `MANAGER_MINING`, `MANAGER_FARMING`).
* Maintains the "Job Queue" (e.g., list of chunks to mine).
* Assigns jobs to idle turtles.
* Handles collision/traffic logic for its specific zone.


* **Logic:** State Machine.

### Tier 3: The Workers (Execution)

* **Hardware:** Advanced Turtle, Ender Modem, Crafting/Tool peripheral.
* **Role:** The "Thick Client" Agent.
* **Responsibilities:**
* Execute complex tasks autonomously (e.g., "Quarry 16x16 area").
* Local pathfinding and error handling (gravel, lava, inventory full).
* Periodically "Push" status updates to their Manager.
* Check for Firmware Updates on boot.



---

## 2. The Protocol (HiveNet v1)

All devices communicate using strictly typed tables serialized by `textutils`.

**Standard Packet Structure:**

```lua
{
  protocol = "HIVE_V1",
  senderID = 12,       -- os.getComputerID()
  targetID = 5,        -- Destination ID (or -1 for Broadcast)
  role     = "MINER",  -- The sender's role
  type     = "...",    -- The message type (defined below)
  payload  = { ... }   -- The actual data
}

```

**Core Message Types:**

| Type | Direction | Payload Example | Description |
| --- | --- | --- | --- |
| `HEARTBEAT` | Worker -> Manager | `{ fuel=500, state="MINING", x=10, y=60, z=10 }` | Routine status update. |
| `JOB_REQUEST` | Worker -> Manager | `{ capacity=16 }` | "I am idle and empty, give me work." |
| `JOB_ASSIGN` | Manager -> Worker | `{ job="QUARRY", param={x=100, z=200} }` | "Go here and do this." |
| `FW_CHECK` | Worker -> Base | `{ current_version="1.0" }` | "Is there a new update?" |
| `FW_PUSH` | Base -> Worker | `{ version="1.1", code="...string..." }` | "Here is the new code." |

---

## 3. File Structure & Logic Flow

### A. The Base Computer

We use the **Component Controller** pattern (Modules + Main Loop).

* `startup.lua`: The Main Loop. Listens to `rednet`, routes messages to `state.lua`, triggers `monitor.lua`.
* `/modules/state.lua`: Holds the big table of all connected managers and their stats. Saves to `disk/state.json`.
* `/modules/monitor.lua`: Reads `state` and draws the UI.
* `/repo/`: Directory containing source code for turtles (e.g., `/repo/miner.lua`).

### B. The Manager Computer

* `startup.lua`: Initializes the specific role (e.g., "I am a Miner Manager").
* `/jobs/`: A queue of pending tasks (saved to disk so jobs aren't lost on reboot).
* `logic.lua`: The brain. Receives `JOB_REQUEST`, pops a job from queue, sends `JOB_ASSIGN`.

### C. The Worker Turtle

* `startup.lua`:
1. **Boot Phase:** Ping Base for Firmware Update. If new, download & reboot.
2. **Discovery Phase:** Ping generic "MANAGER" channel. Wait for assignment to a Manager ID.
3. **Work Phase:** Enter the `main_loop`.


* `worker_core.lua`: The actual logic (movement, digging). It runs a parallel thread to listen for "ABORT" commands.

---

## 4. Implementation Roadmap

We will build this vertically, starting with the simplest complete loop.

### Phase 1: The "Hello World" Loop

* **Goal:** A single Mining Turtle talks to a Base Computer.
* **Tasks:**
1. Setup Base Computer with `startup.lua` that simply prints received messages.
2. Write a `connection_test.lua` for the Turtle that sends a `HEARTBEAT` packet.
3. Verify the Base receives and decodes the packet.



### Phase 2: The Dashboard & State

* **Goal:** Base Computer remembers the Turtle and displays it on the Monitor.
* **Tasks:**
1. Implement `modules/state.lua` on Base to save the Turtle's ID and Fuel level.
2. Implement `modules/monitor.lua` to draw a table of active turtles.
3. Implement `textutils` serialization to save this state to disk.



### Phase 3: The Manager & Job Assignment

* **Goal:** Introduce the middle-man. Turtle asks for work, Manager gives it.
* **Tasks:**
1. Build the Manager Computer.
2. Write the Manager's `job_queue` logic (simple list of coordinates).
3. Update Turtle to send `JOB_REQUEST` instead of just sitting idle.
4. Verify Turtle receives `JOB_ASSIGN` and moves to the target.



### Phase 4: The Firmware Pipeline

* **Goal:** Auto-updating turtles.
* **Tasks:**
1. Create `/repo/` on Base Computer.
2. Add `FW_CHECK` logic to Turtle startup.
3. Write the file-writing logic on the Turtle (receiving code string -> saving to `.lua` file).
