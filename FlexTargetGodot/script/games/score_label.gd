extends Label

func _ready() -> void:
	# Create tween animation: float up and fade out
	var tween = create_tween()
	tween.set_parallel(true)  # Run animations in parallel
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	
	# Float up
	tween.tween_property(self, "position:y", position.y - 100, 1.0)
	
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	
	# Remove after animation
	await tween.finished
	queue_free()

func display_score(score: int) -> void:
	text = "+%d" % score
