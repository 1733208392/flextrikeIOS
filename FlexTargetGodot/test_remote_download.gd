extends Node

# Test for remote file download with verification
# This tests the download_and_verify() function against a real remote file

var test_results = []
var passed = 0
var failed = 0

class DownloadState:
	var download_success: bool = false
	var callback_called: bool = false
	var callback_version: String = ""
	var last_progress: float = 0.0

func _ready():
	print("\n=== Remote File Download Test ===\n")
	print("[TEST] Starting remote file download integration test...")
	print("[TEST] Note: This test requires network access and will take 1-5 minutes\n")
	
	# Ensure OTA directory exists
	var ota_dir = "/Users/kai/otatest"
	if not DirAccess.dir_exists_absolute(ota_dir):
		print("[TEST] Creating OTA directory: %s" % ota_dir)
		DirAccess.make_dir_absolute(ota_dir)
	else:
		print("[TEST] OTA directory confirmed: %s" % ota_dir)
	
	# Run the remote download test
	await test_remote_file_download()
	
	print_results()
	print("[TEST] Test complete. Exiting in 1 second...")
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func test_remote_file_download():
	"""Test downloading and verifying a real remote file"""
	print("Starting remote file download test...")
	
	var remote_url = "https://etarget.topoint-archery.cn/static/ota/game/202601/a918ee65-35f5-40a3-adb9-05f89caddd35.zip"
	var expected_checksum = "b0148f09c3904203d13c7febc799be41fd73cb0c"
	var version = "test_remote_202601"
	
	# Create HttpService instance for testing
	var http_service = load("res://script/HttpService.gd").new()
	add_child(http_service)
	
	# Use a class to hold state to avoid lambda capture issues
	var state = DownloadState.new()
	
	# Connect to download progress signal
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		signal_bus.download_progress.connect(func(progress: float):
			state.last_progress = progress
			if int(progress) % 2 == 0 and progress > 0:
				print("[PROGRESS] Download: %d%%" % int(progress))
		)
	
	# Create callback that will be called when download is complete
	var callback = func(success: bool, version_str: String):
		state.download_success = success
		state.callback_called = true
		state.callback_version = version_str
		print("[TEST] Download callback received - Success: %s, Version: %s" % [success, version_str])
	
	# Call the download function
	print("[TEST] Downloading from: %s" % remote_url)
	print("[TEST] Expected checksum: %s" % expected_checksum)
	print("[TEST] Initiating download...\n")
	
	http_service.download_and_verify(remote_url, expected_checksum, version, callback)
	
	# Wait for the download to complete (with timeout)
	var timeout = 300.0  # 5 minute timeout for real network download
	var elapsed = 0.0
	var poll_interval = 2.0
	var last_progress_report = 0.0
	
	print("[TEST] Waiting for callback (max %.0f seconds)..." % timeout)
	
	while not state.callback_called and elapsed < timeout:
		# Report status periodically
		if int(elapsed) % 20 == 0 and elapsed > 0:
			print("[TEST]   ⏳ Still downloading... %d seconds elapsed (Progress: %d%%)" % [int(elapsed), int(state.last_progress)])
		
		# Also report significant progress changes every 2%
		if state.last_progress > last_progress_report + 2.0:
			last_progress_report = state.last_progress
			print("[PROGRESS] Download: %d%%" % int(state.last_progress))
		
		await get_tree().create_timer(poll_interval).timeout
		elapsed += poll_interval
	
	if not state.callback_called:
		failed += 1
		test_results.append({
			"name": "test_remote_file_download",
			"passed": false,
			"message": "Download callback was not called within timeout (%.1f seconds)" % timeout
		})
		print("[FAIL] Download timed out after %.1f seconds" % elapsed)
		return
	
	# Verify the callback was successful
	if state.download_success and state.callback_version == version:
		passed += 1
		test_results.append({
			"name": "test_remote_file_download",
			"passed": true,
			"message": "Successfully downloaded and verified remote file with correct checksum"
		})
		print("[PASS] Remote file downloaded and verified successfully")
		print("       File: %s" % remote_url)
		print("       Checksum verified: %s" % expected_checksum)
	else:
		failed += 1
		test_results.append({
			"name": "test_remote_file_download",
			"passed": false,
			"message": "Download failed or callback returned incorrect version (success=%s, expected_version=%s, got_version=%s)" % [
				state.download_success, version, state.callback_version
			]
		})
		print("[FAIL] Remote file download verification failed")
		print("       Success: %s" % state.download_success)
		print("       Expected version: %s" % version)
		print("       Callback version: %s" % state.callback_version)

func print_results():
	print("\n" + "=".repeat(60))
	print("TEST RESULTS")
	print("=".repeat(60))
	
	for result in test_results:
		var status = "✓ PASS" if result["passed"] else "✗ FAIL"
		print("%s: %s" % [status, result["name"]])
		print("       %s" % result["message"])
	
	print("=".repeat(60))
	print("Summary: %d passed, %d failed (total: %d)" % [passed, failed, passed + failed])
	print("=".repeat(60) + "\n")

func _process(_delta: float) -> void:
	# Required for headless execution
	pass
