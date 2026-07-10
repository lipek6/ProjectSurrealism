# **Physics Prop Architecture**

**Engine:** Godot 4.x (Jolt Physics)  
**Script:** physics\_prop.gd

## **1\. Overview**

The PhysicsProp class is a generic, highly scalable wrapper for RigidBody3D. It is designed to act as the unified foundation for every interactable physics object in the game (crates, barrels, debris). It handles complex player-riding stabilization, dynamic editor scaling, and mass calculation.

## **2\. Core Architectural Philosophies**

### **Inversion of Control**

Instead of attaching a complex Area3D to every single crate in the world to constantly scan for the player, the prop is entirely passive. The Player's downward raycast scans the floor, finds the prop, and explicitly calls notify\_stepped\_on() and notify\_stepped\_off().

* **Why?** It is massively more performant. If you have 500 crates in a room, 0 of them are running sensor checks. Only the 1 Player is running a check. It also prevents bugs where a tumbling crate's sensor hits a wall and thinks a player stepped on it.

### **Tool Scripting (@tool)**

The script runs in the Godot Editor viewport. By tying prop\_scale to a setter function, Level Designers can scale crates directly in the Inspector, and the script will automatically scale the underlying visual meshes and collision shapes.

* **Why?** Scaling a RigidBody3D directly breaks physics engine calculations. This abstracts the safe scaling method away from the designer. Furthermore, it automatically calculates the physical mass based on volumetric scaling.

## **3\. Riding Mechanics (The "Turntable" Glitch)**

When a player runs across the top of a physics box, the physics engine applies horizontal friction to the top surface. Because the center of mass drags below it, this creates massive **Torque**, causing the box to spin like a turntable and violently buck the player off.

### **The Asymmetric Axis Lock**

When allow\_edge\_teetering is enabled, stepping on the box permanently locks the **Y-Axis (Yaw)**.

* **Result:** The friction of the player's footsteps can no longer spin the box horizontally. However, the X (Pitch) and Z (Roll) axes remain unlocked, meaning the box can still physically teeter and fall off ledges.

### **The Inertia Tensor Trick (Friction Neutralization)**

To further bulletproof the box without "mushy" dampening, we dynamically manipulate the object's inertia (its rotational mass/resistance).

* **How it works:** When stood upon, we multiply the box's inertia by 100.0. It becomes mathematically impossible for the tiny friction of a footstep to generate enough torque to wobble the box.  
* **The Counter-Balance:** Because the box's inertia is 100x stronger, it won't tip off a ledge either. To fix this, when the Player injects Artificial Gravity via apply\_resting\_weight(), the prop *also* multiplies that incoming artificial gravity by 100.0. The player's deliberate weight easily overcomes the inertia, causing a flawless, realistic tip off the ledge.

## **4\. Property Reference**

### **Prop Configuration**

| Property | Type | Description |
| :---- | :---- | :---- |
| prop\_type | PropType | Enum. If SMALL\_DEBRIS, riding mechanics are completely ignored. |
| ignore\_player\_friction | bool | Toggles the Inertia Tensor Trick. Stabilizes the box without axis locking. |
| prop\_scale | Vector3 | Safe scaler. Triggers \_update\_scale\_and\_mass() upon change. |
| auto\_calculate\_mass | bool | If true, applies Volumetric mass logic. A 2x2x2 scale multiplies the mass by 8\. |
| base\_mass | float | The mass of the object when the scale is (1, 1, 1). |

### **Riding Settings**

| Property | Type | Description |
| :---- | :---- | :---- |
| allow\_edge\_teetering | bool | If false, completely locks X, Y, and Z when stood upon, turning the prop into an immovable platformer-style platform. |
| on\_top\_linear\_damp | float | Heavily restricts sliding when stood upon, preventing the box from acting like an ice skate. |

## **5\. Method Reference**

### **notify\_stepped\_on(body: Node3D)**

Called explicitly by the Player's floor manager. Triggers the deployment of the player's flat feet, increments the bodies\_on\_top counter, and triggers the Asymmetric locks and Inertia Tensor multipliers to stabilize the crate.

### **notify\_stepped\_off(body: Node3D)**

Restores the prop's original angular dampening, unlocks the axes, and restores the original inertia tensor, returning the prop to a standard, reactive physics object.

### **apply\_resting\_weight(force: Vector3, point: Vector3)**

Accepts a continuous downward force from the player. It calculates the Lever Arm (the distance from the contact point to the global\_position center of mass) to dynamically apply Torque, allowing the player to realistically tip the object over by standing on its extreme edge.