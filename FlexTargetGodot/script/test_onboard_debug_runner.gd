extends Node

func _ready() -> void:
    # Emit a few test messages via SignalBus if present, otherwise print
    var sb = get_node_or_null("/root/SignalBus")
    if not sb:
        # print("TestOnboardDebugRunner: SignalBus not available, creating temporary test emissions")
        for i in range(3):
            # print("Test message", i)
            pass
        return

    # Emit different priority messages
    # print("TestOnboardDebugRunner: Emitting onboard debug messages via SignalBus")
    # print("emit -> (1, Initialization complete, System)")
    sb.emit_onboard_debug_info(1, "Initialization complete", "System")
    # print("emit -> (2, Network link established, Netlink)")
    sb.emit_onboard_debug_info(2, "Network link established", "Netlink")
    # print("emit -> (0, Low-level sensor data: OK, Sensors)")
    sb.emit_onboard_debug_info(0, "Low-level sensor data: OK", "Sensors")
    # Also emit a longer message to ensure scrolling
    # print("emit -> (3, Verbose multi-line, Diagnostics)")
    sb.emit_onboard_debug_info(3, "Verbose: detailed debug blob...\nLine2\nLine3", "Diagnostics")
    # print("TestOnboardDebugRunner: Emissions complete")
