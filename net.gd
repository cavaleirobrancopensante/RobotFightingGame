## (1.149) Fights with a friend, live. No server of our own: both games talk through a public MQTT
## broker over a secure WebSocket (works in the browser, on phones and computers), on a topic named
## after a five-letter room code. The host runs the fight; the guest sends its pad and watches the
## host's frames (the clip format, fight.gd "live with a friend"). This is the pipe: a tiny MQTT 3.1.1
## client (CONNECT, SUBSCRIBE, PUBLISH at QoS 0, PING) and JSON messages on two topics per room.
extends Node

signal got(msg: Dictionary)          # a message from the other side
signal state_changed(state: String)  # "off", "connecting", "waiting", "ready", "lost", "error"

## Free public brokers, tried in order until one answers.
const BROKERS := ["wss://broker.emqx.io:8084/mqtt", "wss://broker.hivemq.com:8884/mqtt", "wss://test.mosquitto.org:8081/mqtt"]
const TOPIC := "robotfighting/v1/"
const LETTERS := "ABCDEFGHJKMNPQRSTUVWXYZ"   # no I, L or O: they read as numbers
const CODE_LEN := 5
const CONNECT_WAIT := 6.0     # seconds before trying the next broker
const KEEPALIVE := 30
const QUIET := 8.0            # nothing from the other side this long = the line is lost

var brokers: Array = BROKERS.duplicate()   # tests point this at a local broker
var ws: WebSocketPeer = null
var state := "off"
var role := ""                # "host" or "guest"
var code := ""
var broker_i := 0
var wait_t := 0.0
var ping_t := 0.0
var heard_t := 0.0            # seconds since the other side last said anything
var mqtt_up := false
var conn_sent := false
var buf := PackedByteArray()
var client_id := ""
var rtt := 0.0                # measured round trip, seconds
var ping_sent := {}           # ping id -> time sent
var hb_t := 0.0
# what the fight reads (kept here so nothing is lost while a scene loads)
var knock_data := {}          # guest: who we are (sent until the host starts)
var knock_t := 0.0
var last_input := {}          # host: the guest's latest pad
var frames: Array = []        # guest: the host's frames, in order
var start_msg := {}           # guest: the host's "start"
var end_msg := {}             # guest: the host's "end"
var guest_msg := {}           # host: the guest's knock


func clear() -> void:
	last_input = {}
	frames = []
	start_msg = {}
	end_msg = {}
	guest_msg = {}
	knock_data = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func make_code() -> String:
	var r := RandomNumberGenerator.new()
	r.randomize()
	var s := ""
	for k in CODE_LEN:
		s += LETTERS[r.randi() % LETTERS.length()]
	return s


## Clean a code someone typed: capitals, no spaces, I / L read as 1 are fixed.
static func clean_code(s: String) -> String:
	var out := ""
	for ch in s.strip_edges().to_upper():
		if LETTERS.contains(ch):
			out += ch
	return out


func host() -> String:
	start("host", make_code())
	return code


func join(room: String) -> void:
	start("guest", clean_code(room))


func start(as_role: String, room: String) -> void:
	var kd := knock_data
	stop()
	clear()
	knock_data = kd
	rtt = 0.0
	role = as_role
	code = room
	broker_i = 0
	var r := RandomNumberGenerator.new()
	r.randomize()
	client_id = "rf%s%x" % [role[0], r.randi()]
	set_process(true)
	_open()


func stop() -> void:
	if ws != null and mqtt_up:
		_send_raw(PackedByteArray([0xE0, 0x00]))   # DISCONNECT
	if ws != null:
		ws.close()
	ws = null
	mqtt_up = false
	buf = PackedByteArray()
	set_process(false)
	_set_state("off")


func _set_state(s: String) -> void:
	if s != state:
		state = s
		state_changed.emit(s)


func _open() -> void:
	if broker_i >= brokers.size():
		_set_state("error")
		set_process(false)
		return
	ws = WebSocketPeer.new()
	ws.supported_protocols = PackedStringArray(["mqtt"])
	ws.inbound_buffer_size = 1 << 20
	ws.outbound_buffer_size = 1 << 20
	mqtt_up = false
	conn_sent = false
	buf = PackedByteArray()
	wait_t = 0.0
	_set_state("connecting")
	if ws.connect_to_url(str(brokers[broker_i])) != OK:
		broker_i += 1
		_open()


func _process(delta: float) -> void:
	if ws == null:
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not conn_sent:
			conn_sent = true
			_send_raw(_connect_packet())
		while ws.get_available_packet_count() > 0:
			buf.append_array(ws.get_packet())
		_read_packets()
	elif st == WebSocketPeer.STATE_CLOSED:
		if mqtt_up:
			_set_state("lost")
			ws = null
			set_process(false)
			return
		broker_i += 1   # this broker didn't take us: the next one
		_open()
		return
	wait_t += delta
	if not mqtt_up and wait_t > CONNECT_WAIT:
		ws.close()
		ws = null
		broker_i += 1
		_open()
		return
	if mqtt_up:
		ping_t += delta
		if ping_t > KEEPALIVE * 0.5:
			ping_t = 0.0
			_send_raw(PackedByteArray([0xC0, 0x00]))   # PINGREQ
		heard_t += delta
		if state == "ready" and heard_t > QUIET:
			_set_state("lost")
		hb_t += delta
		if hb_t > 2.0:
			hb_t = 0.0
			send({"t": "hb"})
		if role == "guest" and start_msg.is_empty() and state != "lost":
			knock_t += delta
			if knock_t > 2.0:
				knock_t = 0.0
				send({"t": "knock", "g": knock_data})   # until the host answers


func _send_raw(b: PackedByteArray) -> void:
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send(b, WebSocketPeer.WRITE_MODE_BINARY)


static func _len_bytes(n: int) -> PackedByteArray:
	var out := PackedByteArray()
	while true:
		var b := n % 128
		n = n / 128
		if n > 0:
			b |= 128
		out.append(b)
		if n == 0:
			break
	return out


static func _str(s: String) -> PackedByteArray:
	var u := s.to_utf8_buffer()
	var out := PackedByteArray([u.size() >> 8, u.size() & 255])
	out.append_array(u)
	return out


func _packet(kind: int, body: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray([kind])
	out.append_array(_len_bytes(body.size()))
	out.append_array(body)
	return out


func _connect_packet() -> PackedByteArray:
	var body := _str("MQTT")
	body.append_array(PackedByteArray([4, 0x02, KEEPALIVE >> 8, KEEPALIVE & 255]))   # level 4, clean session
	body.append_array(_str(client_id))
	return _packet(0x10, body)


func _my_topic() -> String:
	return TOPIC + code + ("/h" if role == "host" else "/g")


func _their_topic() -> String:
	return TOPIC + code + ("/g" if role == "host" else "/h")


func _read_packets() -> void:
	while buf.size() >= 2:
		var mul := 1
		var n := 0
		var i := 1
		var ok := false
		while i < buf.size() and i < 5:
			n += (buf[i] & 127) * mul
			mul *= 128
			i += 1
			if buf[i - 1] & 128 == 0:
				ok = true
				break
		if not ok or buf.size() < i + n:
			return   # not all here yet
		var kind := buf[0] >> 4
		var body := buf.slice(i, i + n)
		buf = buf.slice(i + n)
		match kind:
			2:   # CONNACK
				if body.size() >= 2 and body[1] == 0:
					mqtt_up = true
					var sub := PackedByteArray([0, 1])
					sub.append_array(_str(_my_topic()))
					sub.append(0)
					_send_raw(_packet(0x82, sub))
				else:
					ws.close()
			9:   # SUBACK: we're listening
				_set_state("waiting")
				if role == "guest":
					send({"t": "knock", "g": knock_data})
			3:   # PUBLISH (QoS 0)
				var tl := (body[0] << 8) | body[1]
				var payload := body.slice(2 + tl).get_string_from_utf8()
				var msg = JSON.parse_string(payload)
				if msg is Dictionary:
					heard_t = 0.0
					_on_msg(msg)


func _on_msg(msg: Dictionary) -> void:
	match str(msg.get("t", "")):
		"ping":
			send({"t": "pong", "id": msg.get("id", 0)})
			return
		"pong":
			var id := int(msg.get("id", 0))
			if ping_sent.has(id):
				var now := Time.get_ticks_msec() / 1000.0
				var r := now - float(ping_sent[id])
				rtt = r if rtt == 0.0 else lerpf(rtt, r, 0.3)
				ping_sent.erase(id)
			return
		"bye":
			_set_state("lost")
			got.emit(msg)
			return
		"hb":
			if state == "waiting":
				_set_state("ready")
			return
		"i":
			last_input = msg
		"f":
			frames.append(msg)
		"start":
			start_msg = msg
		"end":
			end_msg = msg
		"knock":
			if not guest_msg.is_empty():
				return   # already let in
			guest_msg = msg
	if state == "waiting":
		_set_state("ready")
	got.emit(msg)


## Send a message to the other side (JSON).
func send(msg: Dictionary) -> void:
	if not mqtt_up:
		return
	var body := _str(_their_topic())
	body.append_array(JSON.stringify(msg).to_utf8_buffer())
	_send_raw(_packet(0x30, body))


func ping() -> void:
	var id := randi() % 100000
	ping_sent[id] = Time.get_ticks_msec() / 1000.0
	send({"t": "ping", "id": id})


func connected() -> bool:
	return state == "ready"
