class_name Sounds
extends RefCounted
## Placeholder sounds synthesised in code (own work, no asset files).

const MIX_RATE: int = 22050


## Low-HP alarm: three short two-tone beeps.
static func warning() -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	var beep: float = 0.11
	var gap: float = 0.05
	for i: int in 3:
		_tone(data, 880.0, beep, 0.5)
		_tone(data, 660.0, beep, 0.5)
		_tone(data, 0.0, gap, 0.0)
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


## Appends a square-ish tone (soft edges) as 16-bit little-endian samples.
static func _tone(data: PackedByteArray, freq: float, seconds: float, volume: float) -> void:
	var count: int = int(seconds * MIX_RATE)
	var fade: int = int(0.006 * MIX_RATE)
	for n: int in count:
		var t: float = float(n) / MIX_RATE
		var s: float = 0.0
		if freq > 0.0:
			s = clampf(sin(TAU * freq * t) * 3.0, -1.0, 1.0) * volume
			s *= clampf(minf(n, count - n) / float(maxi(fade, 1)), 0.0, 1.0)
		var v: int = clampi(roundi(s * 32767.0), -32768, 32767)
		if v < 0:
			v += 65536
		data.append(v & 0xFF)
		data.append((v >> 8) & 0xFF)
