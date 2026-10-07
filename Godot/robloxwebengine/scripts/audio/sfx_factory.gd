class_name SfxFactory
extends RefCounted
## Genera effetti sonori procedurali come AudioStreamWAV (nessun asset esterno).
## I suoni sono cachati: la prima chiamata genera, le successive riusano.

const MIX_RATE := 22050
const TAIL_FACTOR := 3.0

static var _cache: Dictionary = {}


static func jump() -> AudioStreamWAV:
	return _cached("jump")


static func land() -> AudioStreamWAV:
	return _cached("land")


static func collect() -> AudioStreamWAV:
	return _cached("collect")


static func checkpoint() -> AudioStreamWAV:
	return _cached("checkpoint")


static func death() -> AudioStreamWAV:
	return _cached("death")


static func goal() -> AudioStreamWAV:
	return _cached("goal")


static func _cached(key: String) -> AudioStreamWAV:
	if not _cache.has(key):
		match key:
			"jump":
				_cache[key] = _sweep(280.0, 640.0, 0.16, 0.5)
			"land":
				_cache[key] = _sweep(220.0, 110.0, 0.12, 0.55)
			"collect":
				_cache[key] = _notes([880.0, 1318.5], 0.09, 0.5)
			"checkpoint":
				_cache[key] = _notes([523.25, 659.25, 783.99], 0.11, 0.5)
			"death":
				_cache[key] = _sweep(440.0, 90.0, 0.5, 0.55)
			"goal":
				_cache[key] = _notes([523.25, 659.25, 783.99, 1046.5], 0.14, 0.55)
	return _cache[key]


static func _sweep(from_hz: float, to_hz: float, duration: float, volume: float) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		var frequency := lerpf(from_hz, to_hz, t)
		phase += TAU * frequency / MIX_RATE
		var envelope := minf(t * 40.0, 1.0) * pow(1.0 - t, 2.0)
		samples[i] = sin(phase) * envelope * volume
	return _make(samples)


static func _notes(frequencies: Array, note_duration: float, volume: float) -> AudioStreamWAV:
	var total_time := note_duration * (frequencies.size() + TAIL_FACTOR)
	var count := int(total_time * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / MIX_RATE
		var value := 0.0
		for n in frequencies.size():
			var start := n * note_duration
			if t >= start:
				var local := t - start
				value += sin(TAU * frequencies[n] * local) * exp(-local * 6.0)
		samples[i] = value / frequencies.size() * volume
	return _make(samples)


static func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	stream.data = bytes
	return stream
