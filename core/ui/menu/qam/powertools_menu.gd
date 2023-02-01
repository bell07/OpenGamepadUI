extends VBoxContainer

const powertools_path : String = "/etc/handypt/powertools"

var boost_capable := false
var core_count := 0
var cpu_model := ""
var cpu_vendor := ""
var gpu_clk_capable := false
var gpu_model := ""
var gpu_vendor := ""
var ht_capable := false
var tdp_capable := false
var tj_temp_capable := false

@onready var cpu_boost_button := $CPUBoostButton
@onready var cpu_cores_slider := $CPUCoresSlider
@onready var gpu_freq_enable := $GPUFreqButton
@onready var gpu_freq_max_slider := $GPUFreqMaxSlider
@onready var gpu_freq_min_slider := $GPUFreqMinSlider
@onready var gpu_temp_slider := $GPUTempSlider
@onready var smt_button := $SMTButton
@onready var tdp_boost_slider := $TDPBoostSlider
@onready var tdp_slider := $TDPSlider

@export var focus_node : Node = $CPUBoostButton

# Called when the node enters the scene tree for the first time.
# Finds default values and current settings of the hardware.
func _ready():

	_get_system_components()

	# Set UI capabilities from system capabilities
	cpu_boost_button.visible = boost_capable
	cpu_cores_slider.visible = ht_capable
	gpu_freq_enable.visible = gpu_clk_capable
	gpu_temp_slider.visible = tj_temp_capable
	smt_button.visible = ht_capable
	tdp_boost_slider.visible = tdp_capable
	tdp_slider.visible = tdp_capable

	if tdp_capable:
		_get_tdp_range()
		_get_current_tdp_settings()
		tdp_boost_slider.value_changed.connect(_on_tdp_boost_value_changed)
		tdp_slider.value_changed.connect(_on_tdp_value_changed)

	if gpu_clk_capable:
		_get_gpu_clk_limits()
		if read_sys("/sys/class/drm/card0/device/power_dpm_force_performance_level") == "manual":
			gpu_freq_enable.button_pressed = true
			gpu_freq_max_slider.visible = true
			gpu_freq_min_slider.visible = true
		gpu_freq_enable.toggled.connect(_on_toggle_gpu_freq)
		gpu_freq_max_slider.value_changed.connect(_on_max_gpu_freq_changed)
		gpu_freq_min_slider.value_changed.connect(_on_min_gpu_freq_changed)

		# Set write mode for power_dpm_force_performance_level
		var output = []
		var exit_code := OS.execute(powertools_path, ["pdfpl", "write"], output)

	if ht_capable:
		if read_sys("/sys/devices/system/cpu/smt/control") == "on":
			smt_button.button_pressed = true
		_get_cpu_count()
		cpu_cores_slider.value_changed.connect(_on_change_cpu_cores)
		smt_button.toggled.connect(_on_toggle_smt)

	if boost_capable:
		if read_sys("/sys/devices/system/cpu/cpufreq/boost") == "1":
			cpu_boost_button.button_pressed = true
		cpu_boost_button.toggled.connect(_on_toggle_cpu_boost)

	if tj_temp_capable:
		gpu_temp_slider.value_changed.connect(_on_gpu_temp_limit_changed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func read_sys(path: String) -> String:
	var output = []
	var exit_code := OS.execute("cat", [path], output)
	return output[0].strip_escapes()


func _get_cpu_count() -> bool:
	var args = ["-c", "ls /sys/bus/cpu/devices/ | wc -l"]
	var output := []
	var exit_code := OS.execute("bash", args, output)
	if exit_code:
		return false
	var result := output[0].split("\n") as Array
	core_count = int(result[0])
	if smt_button.button_pressed:
		cpu_cores_slider.max_value = core_count
	else:
		cpu_cores_slider.max_value = core_count / 2
	cpu_cores_slider.value = _get_cpus_enabled()
	return true


func _get_cpus_enabled() -> int:
	pass
	var active_cpus := 1
	for i in range(1, core_count):
		var args = ["-c", "cat /sys/bus/cpu/devices/cpu"+str(i)+"/online"]
		var output := []
		var exit_code := OS.execute("bash", args, output)
		active_cpus += int(output[0].strip_edges())

	return active_cpus


func _get_gpu_clk_limits() -> bool:
	var args := ["/sys/class/drm/card0/device/pp_od_clk_voltage"]
	var output := []
	var exit_code := OS.execute("cat", args, output)
	var result := output[0].split("\n") as Array
	var current_max := 0
	var current_min := 0
	var max_value := 0
	var min_value := 0

	for param in result:
		var parts := param.split("\n") as Array
		for part in parts:
			part = part.strip_edges().split(" ", false)
			if part.is_empty():
				continue
			if part[0] == "SCLK:":
				min_value = int(part[1].rstrip("Mhz"))
				max_value = int(part[2].rstrip("Mhz"))
			elif part[0] == "0:":
				current_min =  int(part[1].rstrip("Mhz"))
			elif part[0] == "1:":
				current_max =  int(part[1].rstrip("Mhz"))

	gpu_freq_max_slider.max_value = max_value
	gpu_freq_max_slider.min_value = min_value
	gpu_freq_max_slider.value = current_max
	gpu_freq_min_slider.max_value = max_value
	gpu_freq_min_slider.min_value = min_value
	gpu_freq_min_slider.value = current_min
	return true


func _get_current_tdp_settings() -> bool:
	var output := []
	var exit_code := OS.execute(powertools_path, ["ryzenadj", "-i"], output)
	var result := output[0].split("\n") as Array
	if exit_code:
		return false

	var current_fastppt := 0.0
	for setting in result:
		var parts := setting.split("|") as Array
		var i := 0
		for part in parts:
			parts[i] = part.strip_edges()
			i+=1
		if len(parts) < 3:
			continue
		match parts[1]:
			"PPT LIMIT FAST":
				current_fastppt = float(parts[2])
			"STAPM LIMIT":
				tdp_slider.value = float(parts[2])
			"THM LIMIT CORE":
				gpu_temp_slider.value = float(parts[2])
	var current_boost = current_fastppt - tdp_slider.value 

	if current_boost > tdp_boost_slider.max_value:
		_on_tdp_boost_value_changed(tdp_boost_slider.max_value)
	elif current_boost <= 0:
		_on_tdp_boost_value_changed(0)
	else:
		_on_tdp_boost_value_changed(current_boost)

	return true	


func _get_system_components() -> bool:
	var output = []
	var args = ["-c", "lscpu"]
	var exit_code := OS.execute("bash", args, output)
	if exit_code:
		return false
	var result := output[0].split("\n") as Array
	for param in result:
		var parts := param.split(" ", false) as Array
		if parts.is_empty():
			continue
		if parts[0] == "Flags:":
			if "ht" in parts:
				ht_capable = true
			if "cpb" in parts:
				boost_capable = true

		if parts[0] == "Vendor" and parts[1] == "ID:":
			# Delete parts of the string we don't want
			parts.remove_at(1)
			parts.remove_at(0)
			cpu_vendor = str(" ".join(parts))
		if parts[0] == "Model" and parts[1] == "name:":
			# Delete parts of the string we don't want
			parts.remove_at(1)
			parts.remove_at(0)
			cpu_model = str(" ".join(parts))
		# TODO: We can get min/max CPU freq here.

	if cpu_model == "" or cpu_vendor == "":
		return false

	# TODO: This is lazy and doesn't support dedicated graphics paired with APU's.
	if cpu_model in amd_apu_database:
		gpu_model = cpu_model
		gpu_vendor = cpu_vendor
		tdp_capable = true
		tj_temp_capable = true
		gpu_clk_capable = true

	if gpu_model == "" or gpu_vendor == "":
		return false

	return true


func _get_tdp_range() -> bool:
	if cpu_vendor == "AuthenticAMD":
		if cpu_model in amd_apu_database:
			return _get_tdp_range_amd_apu()
	return false


func _get_tdp_range_amd_apu() -> bool:
	var apu_data := amd_apu_database[cpu_model] as Dictionary
	tdp_boost_slider.max_value = apu_data["max_boost"]
	tdp_slider.max_value = apu_data["max_tdp"]
	tdp_slider.min_value = apu_data["min_tdp"]
	return true


func _on_change_cpu_cores(value: float):
	if smt_button.button_pressed:
		for cpu_no in range(1, core_count):
			var output := []
			if cpu_no > cpu_cores_slider.value - 1:
				var exit_code := OS.execute(powertools_path, ["togglecpu", str(cpu_no), "0"], output)
			else:
				var exit_code := OS.execute(powertools_path, ["togglecpu", str(cpu_no), "1"], output)
			
	else:
		for i in range(1, core_count/2):
			var cpu_no := i * 2
			var output := []
			if cpu_no > cpu_cores_slider.value * 2 - 1:
				
				var exit_code := OS.execute(powertools_path, ["togglecpu", str(cpu_no), "0"], output)
			else:
				var exit_code := OS.execute(powertools_path, ["togglecpu", str(cpu_no), "1"], output)


func _on_gpu_temp_limit_changed(value: float) -> bool:
	var output = []
	var exit_code := OS.execute(powertools_path, ["ryzenadj", "-f", str(value)], output)
	if exit_code:
		return false
	return true


func _on_max_gpu_freq_changed(value: float) -> bool:
	if value < gpu_freq_min_slider.value:
		gpu_freq_min_slider.value = value
	var output = []
	var args = ["gpuclk", "1", str(value)]
	var exit_code := OS.execute(powertools_path, args, output)
	if exit_code:
		return false
	return true


func _on_min_gpu_freq_changed(value: float) -> bool:
	if value > gpu_freq_max_slider.value:
		gpu_freq_max_slider.value = value
	var output = []
	var args = ["gpuclk", "0", str(value)]
	var exit_code := OS.execute(powertools_path, args, output)
	if exit_code:
		return false
	return true


func _on_pressed() -> void:
	focus_node.grab_focus()


func _on_tdp_boost_value_changed(value: float) -> bool:
	var slowPPT: float = (floor(value/2) + tdp_slider.value) * 1000
	var fastPPT: float = (value + tdp_slider.value) * 1000
	var output = []
	var exit_code := OS.execute(powertools_path, ["ryzenadj", "-b", str(fastPPT)], output)
	exit_code = OS.execute(powertools_path, ["ryzenadj", "-c", str(slowPPT)], output)
	if exit_code:
		return false
	return true


func _on_tdp_value_changed(value: float) -> bool:
	var output = []
	var exit_code := OS.execute(powertools_path, ["ryzenadj", "-a", str(value * 1000)], output)
	if exit_code:
		return false
	return _on_tdp_boost_value_changed(tdp_boost_slider.value)


func _on_toggle_cpu_boost(state: bool) -> bool:
	var args := ["cpuBoost", "0"]
	if state:
		args = ["cpuBoost", "1"]
	var output = []
	var exit_code := OS.execute(powertools_path, args, output)
	if exit_code:
		return false
	return true

func _on_toggle_gpu_freq(state: bool):
	var output = []
	if state:
		var exit_code := OS.execute(powertools_path, ["pdfpl", "manual"], output)
		if exit_code:
			return false
		gpu_freq_max_slider.visible = true
		gpu_freq_min_slider.visible = true
		_get_gpu_clk_limits()
		return true
	var exit_code := OS.execute(powertools_path, ["pdfpl", "auto"], output)
	if exit_code:
		return false
	gpu_freq_max_slider.visible = false
	gpu_freq_min_slider.visible = false
	_get_gpu_clk_limits()
	return true

func _on_toggle_smt(state: bool):
	var args := []
	if state:
		args = ["smt", "on"]
		cpu_cores_slider.max_value = core_count
	else:
		args = ["smt", "off"]
		cpu_cores_slider.max_value = core_count / 2

	var output = []
	var exit_code := OS.execute(powertools_path, args, output)
	
	if exit_code:
		return false
		
	cpu_cores_slider.value = _get_cpus_enabled()
	return true


var amd_apu_database := {'AMD Athlon Silver 3020e with Radeon Graphics': { 
		"max_tdp": 12,
		"min_tdp": 2,
		"max_boost": 6
		},
	'AMD Athlon Silver 3050e with Radeon Graphics': {
		"max_tdp": 12,
		"min_tdp": 2,
		"max_boost": 6
		},
	'AMD Ryzen 3 2200U with Radeon Graphics': {
		"max_tdp": 20,
		"min_tdp": 2,
		"max_boost": 5
		},
	'AMD Ryzen 3 2300U with Radeon Graphics': {
		"max_tdp": 25,
		"min_tdp": 2,
		"max_boost": 5
		},
	'AMD Ryzen 3 3200U with Radeon Graphics': {
		"max_tdp": 20,
		"min_tdp": 2,
		"max_boost": 5
		},
	'AMD Ryzen 3 3300U with Radeon Graphics': {
		"max_tdp": 25,
		"min_tdp": 2,
		"max_boost": 5
		},
	'AMD Ryzen 3 4300U with Radeon Graphics': {
		"max_tdp": 23,
		"min_tdp": 2,
		"max_boost": 2
		},
	'AMD Ryzen 3 5125C with Radeon Graphics': {
		"max_tdp": 15,
		"min_tdp": 2,
		"max_boost": 2
		},
	'AMD Ryzen 3 5300U with Radeon Graphics': {
		"max_tdp": 23,
		"min_tdp": 5,
		"max_boost": 2
		},
	'AMD Ryzen 3 5400U with Radeon Graphics': {
		"max_tdp": 23,
		"min_tdp": 5,
		"max_boost": 2
		},
	'AMD Ryzen 3 5425C with Radeon Graphics': {
		"max_tdp": 23,
		"min_tdp": 5,
		"max_boost": 2
		},
	'AMD Ryzen 3 5425U with Radeon Graphics': {
		"max_tdp": 15,
		"min_tdp": 2,
		"max_boost": 2
		},
	'AMD Ryzen 5 2500U with Radeon Graphics': {
		"max_tdp": 25,
		"min_tdp": 5,
		"max_boost": 5
		},
	'AMD Ryzen 5 3500U with Radeon Graphics': {
		"max_tdp": 30,
		"min_tdp": 5,
		"max_boost": 5
		},
	'AMD Ryzen 5 3550H with Radeon Graphics': {
		"max_tdp": 35,
		"min_tdp": 5,
		"max_boost": 5
		},
	'AMD Ryzen 5 4500U with Radeon Graphics': {
		"max_tdp": 28,
		"min_tdp": 5,
		"max_boost": 2
		},
	'AMD Ryzen 5 4600H with Radeon Graphics': {
		"max_tdp": 55,
		"min_tdp": 5,
		"max_boost": 11
		},
	'AMD Ryzen 5 4600HS with Radeon Graphics': {
		"max_tdp": 45,
		"min_tdp": 5,
		"max_boost": 11
		},
	'AMD Ryzen 5 4600U with Radeon Graphics': {
		"max_tdp": 33,
		"min_tdp": 5,
		"max_boost": 5
		},
	'AMD Ryzen 5 5500U with Radeon Graphics': {
		"max_tdp": 28,
		"min_tdp": 5,
		"max_boost": 2
		},
	'AMD Ryzen 5 5560U with Radeon Graphics': {
		"max_tdp": 28,
		"min_tdp": 3,
		"max_boost": 2
		},
	'AMD Ryzen 5 5600H with Radeon Graphics': {
		"max_tdp": 12,
		"min_tdp": 2,
		"max_boost": 6
		},
	'AMD Ryzen 5 5600HS with Radeon Graphics': {
		"max_tdp": 45,
		"min_tdp": 5,
		"max_boost": 11
		},
	'AMD Ryzen 5 5600U with Radeon Graphics': {
		"max_tdp": 33,
		"min_tdp": 5,
		"max_boost": 5
		},
	'AMD Ryzen 5 5625C with Radeon Graphics': {
		"max_tdp": 15,
		"min_tdp": 2,
		"max_boost": 2
		},
	'AMD Ryzen 5 5625U with Radeon Graphics': {
		"max_tdp": 33,
		"min_tdp": 5,
		"max_boost": 5
		},
	'AMD Ryzen 5 6600H with Radeon Graphics': {
		"max_tdp": 58,
		"min_tdp": 5,
		"max_boost": 10
		},
	'AMD Ryzen 5 6600HS with Radeon Graphics': {
		"max_tdp": 45,
		"min_tdp": 5,
		"max_boost": 11
		},
	'AMD Ryzen 5 6600U with Radeon Graphics': {
		"max_tdp": 33,
		"min_tdp": 5,
		"max_boost": 5
		},
	'AMD Ryzen 7 2700U with Radeon Graphics': {
		"max_tdp": 25,
		"min_tdp": 5,
		"max_boost": 5
		},
	'AMD Ryzen 7 3700U with Radeon Graphics': {
		"max_tdp": 30,
		"min_tdp": 5,
		"max_boost": 10
		},
	'AMD Ryzen 7 3750H with Radeon Graphics': {
		"max_tdp": 40,
		"min_tdp": 5,
		"max_boost": 10
		},
	'AMD Ryzen 7 4700U with Radeon Graphics': {
		"max_tdp": 12,
		"min_tdp": 2,
		"max_boost": 6
		},
	'AMD Ryzen 7 4800H with Radeon Graphics': {
		"max_tdp": 60,
		"min_tdp": 5,
		"max_boost": 8
		},
	'AMD Ryzen 7 4800HS with Radeon Graphics': {
		"max_tdp": 50,
		"min_tdp": 5,
		"max_boost": 8
		},
	'AMD Ryzen 7 4800U with Radeon Graphics': {
		"max_tdp": 33,
		"min_tdp": 5,
		"max_boost": 5
		},
	'AMD Ryzen 7 4980U with Radeon Graphics': {
		"max_tdp": 15,
		"min_tdp": 10,
		"max_boost": 10
		},
	'AMD Ryzen 7 5700U with Radeon Graphics': {
		"max_tdp": 28,
		"min_tdp": 5,
		"max_boost": 2
		},
	'AMD Ryzen 7 5800H with Radeon Graphics': {
		"max_tdp": 68,
		"min_tdp": 10,
		"max_boost": 4
		},
	'AMD Ryzen 7 5800HS with Radeon Graphics': {
		"max_tdp": 50,
		"min_tdp": 10,
		"max_boost": 8
		},
	'AMD Ryzen 7 5800U with Radeon Graphics': {
		"max_tdp": 33,
		"min_tdp": 5,
		"max_boost": 5
		},
	'AMD Ryzen 7 5825C with Radeon Graphics': {
		"max_tdp": 15,
		"min_tdp": 10,
		"max_boost": 10
		},
	'AMD Ryzen 7 5825U with Radeon Graphics': {
		"max_tdp": 33,
		"min_tdp": 5,
		"max_boost": 5
		},
	'AMD Ryzen 7 6800H with Radeon Graphics': {
		"max_tdp": 58,
		"min_tdp": 10,
		"max_boost": 10
		},
	'AMD Ryzen 7 6800HS with Radeon Graphics': {
		"max_tdp": 50,
		"min_tdp": 10,
		"max_boost": 8
		},
	'AMD Ryzen 7 6800U with Radeon Graphics': {
		"max_tdp": 33,
		"min_tdp": 5,
		"max_boost": 5
		},
	'AMD Ryzen 9 4900H with Radeon Graphics': {
		"max_tdp": 60,
		"min_tdp": 10,
		"max_boost": 8
		},
	'AMD Ryzen 9 4900HS with Radeon Graphics': {
		"max_tdp": 50,
		"min_tdp": 5,
		"max_boost": 8
		},
	'AMD Ryzen 9 5900HS with Radeon Graphics': {
		"max_tdp": 50,
		"min_tdp": 10,
		"max_boost": 8
		},
	'AMD Ryzen 9 5900HX with Radeon Graphics': {
		"max_tdp": 70,
		"min_tdp": 10,
		"max_boost": 20
		},
	'AMD Ryzen 9 5980HS with Radeon Graphics': {
		"max_tdp": 50,
		"min_tdp": 10,
		"max_boost": 8
		},
	'AMD Ryzen 9 5980HX with Radeon Graphics': {
		"max_tdp": 70,
		"min_tdp": 10,
		"max_boost": 20
		},
	'AMD Ryzen 9 6900HS with Radeon Graphics': {
		"max_tdp": 50,
		"min_tdp": 10,
		"max_boost": 8
		},
	'AMD Ryzen 9 6900HX with Radeon Graphics': {
		"max_tdp": 70,
		"min_tdp": 10,
		"max_boost": 20
		},
	'AMD Ryzen 9 6980HS with Radeon Graphics': {
		"max_tdp": 50,
		"min_tdp": 10,
		"max_boost": 8
		},
	'AMD Ryzen 9 6980HX with Radeon Graphics': {
		"max_tdp": 70,
		"min_tdp": 10,
		"max_boost": 20
		}
}