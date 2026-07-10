# **Player Controller Architecture**

**Engine:** Godot 4.x (Jolt Physics)  
**Script:** player.gd

## **1\. Overview**

The Player Controller is a Kinematic (CharacterBody3D) entity built to replicate the high-skill ceiling, fluid movement of the Source Engine (Half-Life 2, Quake). It features continuous state management, vector-projected acceleration, and highly advanced, glitch-free interactions with dynamic physical objects (RigidBody3D).

## **2\. Core Architectural Philosophies**

### **The Input Struct Pattern (PlayerInput)**

Instead of calling Input.is\_action\_pressed() randomly throughout the physics calculations, all hardware polling happens exactly once at the start of the frame inside \_gather\_inputs(). The results are stored in a "dumb" data container (PlayerInput).

* **Why?** *Separation of Concerns*. If the player's speed is bugged, we know it's a math issue, not a hardware polling issue. It also allows us to easily implement features like "stun" or "cutscene mode" by simply zeroing out the PlayerInput struct before the physics math executes.

### **The Finite State Machine (FSM)**

The controller uses an explicit current\_state enum (e.g., WALKING, IN\_AIR\_CROUCHING) rather than stacking booleans (is\_jumping, is\_crouching).

* **Why?** It prevents "Boolean Hell." A state machine guarantees the player can only execute the physics math relevant to their exact situation, making bugs infinitely easier to trace. State transitions happen strictly inside \_on\_state\_transition(), meaning physical shapes (like hitboxes) only mutate *once* per state change, keeping the physics engine stable.

## **3\. Movement Physics**

### **Vector-Projected Acceleration (Quake Movement)**

Unlike standard controllers that clamp velocity to an input vector, this system calculates acceleration dynamically using the **Dot Product** (velocity.dot(wished\_direction)).

* **How it works:** The system checks how fast the player is *already* moving in the intended direction. If they are below the speed cap for that specific vector, acceleration is applied.  
* **The Result:** This mathematical quirk allows players to curve their jumps (air-strafe) and bypass the forward speed limit by combining forward and lateral inputs mid-air (Bunny Hopping).

### **Kinematic Stair Snapping**

A standard capsule bounces wildly on stairs. We solve this using predictive ghost-casting:

* **Snap Up:** \_snap\_up\_stairs\_check() creates a "ghost" of the player's intended next step, raises it, and casts down. If it hits a valid step, the player is instantly teleported up, creating a perfectly smooth visual ascent.  
* **Snap Down:** \_snap\_down\_to\_stairs\_check() prevents the player from launching horizontally off steps. If the floor suddenly drops beneath the player, a downward raycast detects the next step and instantly teleports the player down to stay glued to the staircase.

## **4\. Physics Interactions (Kinematic vs. Dynamic)**

Because a CharacterBody3D has infinite mass to the physics engine, we must manually program how it interacts with crates and barrels.

### **1\. The "Featherweight" Fix (Momentum Conservation)**

Inside \_push\_away\_rigid\_bodies(), we calculate the mass ratio and velocity differential between the player and the box. We cap the player's pushing force based on their weight.

* **Result:** A 10,000kg box will barely scrape along the floor, while a 0.1kg soda can will instantly match the player's walking speed without launching into orbit.

### **2\. The "Watermelon Seed" Fix (Dynamic Flat Feet)**

When a curved capsule walks off the edge of a box, the sharp 90-degree corner overlaps the curve. The physics engine panics and violently shoots the box away like a squeezed watermelon seed.

* **Result:** We built activate\_collision\_feet\_for\_props(). When standing on a box, the player deploys a hidden, flat BoxShape3D at the soles of their feet, neutralizing the curve glitch entirely.

### **3\. The Floor Guard**

We track exactly which object the player is standing on (\_current\_floor\_prop). If the player's knees bump that specific object while walking on it, \_push\_away\_rigid\_bodies ignores it. This prevents a catastrophic feedback loop where the player punches the box out from under themselves.

### **4\. Artificial Gravity Injection**

Because Kinematic bodies hover 0.0001m above the floor, they don't apply weight to edges.

* **Result:** \_apply\_weight\_to\_floor\_prop() shoots a raycast straight down to get the exact 3D pixel the foot is touching. It calculates Player Mass \* Gravity and injects it directly into the PhysicsProp. If the player stands on the extreme edge of a crate hanging off a cliff, their artificial weight provides the torque needed to realistically tip the crate over.

## **5\. Property Reference**

### **General & Camera**

| Property | Type | Description |
| :---- | :---- | :---- |
| is\_active | bool | Master toggle. If false, completely disables player processing. |
| weight | float | Player mass in kg. Determines maximum pushing force and resting gravity torque. |
| apply\_impulse\_at\_center | bool | If true, pushes objects smoothly from their center. If false, pushes exactly where the knee hits (causes realistic but unpredictable tumbling). |
| headbob | bool | Toggles the procedural sine-wave camera sway tied to velocity. |

### **Ground Movement**

| Property | Type | Description |
| :---- | :---- | :---- |
| auto\_bhop | bool | If true, holding jump instantly triggers a jump upon hitting the floor. |
| ground\_accel | float | The rate at which the player reaches their walking speed cap. |
| ground\_friction | float | Degrades momentum. High \= snappy stops. Low \= slippery ice. |
| max\_step\_height | float | The maximum vertical height (in meters) the stair-snapping logic will climb. |
| crouch\_translate | float | How far down the camera and collision shape shift when crouching. |

### **Air Movement**

| Property | Type | Description |
| :---- | :---- | :---- |
| jump\_velocity | float | Upward impulse applied on jump. |
| air\_cap | float | Maximum speed achievable *purely* from air-strafing vector calculations. |
| air\_accel | float | Extremely high (800) to allow for crisp, Source-engine directional influence mid-air. |
