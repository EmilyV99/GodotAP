extends GridContainer

@onready var ipbox: TypingBar = $IP_Box
@onready var portbox: TypingBar = $Port_Box
@onready var slotbox: TypingBar = $Slot_Box
@onready var pwdbox: TypingBar = $Pwd_Box
@onready var errlbl: Label = $ErrorLabel

func _ready() -> void:
	Archipelago.creds.updated.connect(refresh_creds)
	refresh_creds(Archipelago.creds)
	Archipelago.connected.connect(func(_conn,_json): update_connection(true))
	Archipelago.disconnected.connect(func(): update_connection(false))
func refresh_creds(creds: APCredentials) -> void:
	ipbox.retype(creds.ip)
	portbox.retype(creds.port)
	slotbox.retype(creds.slot)
	pwdbox.retype(creds.pwd)

func update_connection(status: bool) -> void:
	ipbox.disabled = status
	portbox.disabled = status
	slotbox.disabled = status
	pwdbox.disabled = status
func try_connection() -> void:
	if Archipelago.is_not_connected():
		Archipelago.ap_connect(ipbox.text, portbox.text, slotbox.text, pwdbox.text)
		_connect_signals()
		
func kill_connection() -> void:
	Archipelago.ap_disconnect()

func _connect_signals() -> void:
	Archipelago.connected.connect(_on_connect_success)
	Archipelago.connectionrefused.connect(_on_connect_refused)
func _disconnect_signals() -> void:
	Archipelago.connected.disconnect(_on_connect_success)
	Archipelago.connectionrefused.disconnect(_on_connect_refused)
func _on_connect_success(_conn: ConnectionInfo, _json: Dictionary) -> void:
	_disconnect_signals()
	errlbl.text = ""
func _on_connect_refused(_conn: ConnectionInfo, json: Dictionary) -> void:
	_disconnect_signals()
	errlbl.text = "ERROR: " + (", ".join(json.get("errors", ["Unknown"])))
