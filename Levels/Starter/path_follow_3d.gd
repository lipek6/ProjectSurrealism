extends PathFollow3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

var switch_side : bool = false
func _physics_process(delta: float) -> void:
	if self.progress_ratio >= 0.9:
		switch_side = true
	elif self.progress_ratio <= 0.1:
		switch_side = false 
		
	if switch_side:
		progress -= 0.1
	else:
		progress += 0.1
	
	if self.progress_ratio >= 0.5:
		%CrateBig.reparent(owner)
		
		
