extends Node

# Global Debug Control Singleton
# Controls debug output across the entire application

# Master debug control - set to true to disable all debug prints
var DEBUG_DISABLED: bool = true

# Alternative flag for enabling debug (inverse of DEBUG_DISABLED)
var debug_enabled: bool = false

func _ready():
	# Initialize debug state
	debug_enabled = not DEBUG_DISABLED
	print("GlobalDebug initialized: DEBUG_DISABLED = ", DEBUG_DISABLED, ", debug_enabled = ", debug_enabled)

# Method to enable/disable debug globally
func set_debug_enabled(enabled: bool):
	debug_enabled = enabled
	DEBUG_DISABLED = not enabled
	print("GlobalDebug: set_debug_enabled(", enabled, ") - DEBUG_DISABLED = ", DEBUG_DISABLED)

# Method to check if debug is enabled
func is_debug_enabled() -> bool:
	return debug_enabled

# Method to get debug status as string
func get_debug_status() -> String:
	return "DEBUG_DISABLED: " + str(DEBUG_DISABLED) + ", debug_enabled: " + str(debug_enabled)
