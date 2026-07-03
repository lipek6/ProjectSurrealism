# Player Controller Documentation

**Engine:** Godot 4.x
**Project:** ProjectSurrealism
**Script** player.gd

## Overview

The player controller is a custom-built 3D Kinematic system designed to replicate the fluidity and high-skill ceiling of Source-engine games (e.g., Quake, Counter-Strike: Source). It bypasses standard linear movement in favor of vector-projection acceleration, allowing for complex maneuvers like bunny hopping, air strafing, and surfing.

## Architecture: Finite State Machine (FSM)

The character's behavior is governed by a lightweight FSM to prevent overlapping mechanical logic and "boolean hell". State evaluation is centralized within the `_update_player_state()` function.

* `IDLE`: Grounded, no directional input.
* `WALKING`: Grounded, directional input applied, operating below the sprint speed threshold.
* `SPRINTING`: Grounded, directional input applied, operating at maximum ground speed limit.
* `IN_AIR`: Not grounded. Employs vector-projection physics to allow for air-strafing without instantly overriding momentum.
* `SURFING`: Airborne, colliding with a surface exceeding the `floor_max_angle`. Switches the Kinematic body to `MOTION_MODE_FLOATING` to prevent gravity from violently pulling the player off the slope.

## Core Mechanics

### 1. Vector Projection Movement (Quake/Source Style)

Unlike standard controllers that clamp velocity directly to an input vector, this system calculates acceleration dynamically using the **Dot Product**.

* **Mechanic:** `current_speed_in_wished_direction = velocity.dot(wished_direction)`
* **Result:** The system checks how fast the player is *already* moving in the requested direction. If the player is below the speed cap for that specific vector, acceleration is applied. This allows players to curve their jumps (air strafe) and build momentum exponentially by manipulating their mouse and movement keys simultaneously.

### 2. Bunny Hopping (B-Hop)

* Ground friction is applied specifically to the velocity magnitude over time.
* By jumping the exact physics frame the player touches the floor (automated via `auto_bhop`), the friction calculation is bypassed, allowing the player to maintain or increase speed gained from air strafing.

### 3. Surfing & Wall Clipping

When a player collides with a steep wall mid-air, standard physics would halt all momentum.

* **`clip_velocity()`:** This function calculates the back-off velocity needed to prevent the player from penetrating the wall geometry. By subtracting this vector from the player's current velocity, the player's momentum is perfectly redirected to slide *along* the surface.

### Exposed Inspector Parameters

#### Camera Settings

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `look_sensitivity` | Float | `0.006` | Multiplier for raw mouse input to control camera rotation. |
| `controller_look_sensitivity` | Float | `0.075` | Multiplier for gamepad analog stick input to control camera rotation. |
| `headbob` | Boolean | `true` | Toggles the procedural sine-wave camera translation (sway) during movement. |

#### Ground Movement

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `auto_bhop` | Boolean | `true` | Enables continuous jumping by holding the jump input. Bypasses the need for precise frame-perfect inputs upon landing. |
| `auto_sprint` | Boolean | `true` | If true, the character defaults to sprint speed. The sprint action key will invert this behavior to walk. |
| `walk_speed` | Float | `7.0` | Base velocity limit when the player is walking. |
| `sprint_speed` | Float | `8.5` | Base velocity limit when the player is sprinting. |
| `ground_accel` | Float | `14.0` | Multiplier dictating how rapidly the player reaches their grounded speed cap. |
| `ground_decel` | Float | `10.0` | The base threshold used to calculate stopping power when no directional input is provided. |
| `ground_friction` | Float | `6.0` | The friction coefficient applied over time to degrade momentum when grounded. |

#### Air Movement

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `jump_velocity` | Float | `6.0` | The instant Y-axis velocity impulse applied when successfully jumping. |
| `air_cap` | Float | `0.85` | The hard limit for velocity gained specifically via the vector-projection calculation mid-air (prevents infinite instant acceleration). |
| `air_accel` | Float | `800.0` | Multiplier for aerial maneuverability. Kept extremely high to simulate immediate Source-engine directional influence. |
| `air_move_speed` | Float | `500.0` | The theoretical maximum base speed used in the acceleration dot-product formula while airborne. |