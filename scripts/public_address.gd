extends Node

signal changed

const LOOKUP_URL := "https://api.ipify.org"
const CACHE_MSEC := 300000

var lookup_url := LOOKUP_URL
var request_timeout := 8.0
var address := ""
var loading := false
var _request: HTTPRequest
var _last_success_msec := 0


func refresh(force := false) -> void:
	if loading or not is_inside_tree():
		return
	if not force and not address.is_empty() and Time.get_ticks_msec() - _last_success_msec < CACHE_MSEC:
		return
	address = ""
	loading = true
	_request = HTTPRequest.new()
	_request.timeout = request_timeout
	_request.body_size_limit = 64
	_request.max_redirects = 0
	add_child(_request)
	_request.request_completed.connect(_on_request_completed.bind(_request))
	changed.emit()
	if _request.request(lookup_url) != OK:
		_complete(_request, "")


func clear() -> void:
	if _request != null:
		_request.cancel_request()
		_request.queue_free()
		_request = null
	address = ""
	loading = false
	_last_success_msec = 0
	changed.emit()


func controller_url(port: int) -> String:
	return "http://%s:%d/" % [address, port] if not address.is_empty() and port > 0 else ""


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request_node: HTTPRequest) -> void:
	var detected := ""
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var candidate := body.get_string_from_utf8().strip_edges()
		if not candidate.contains(":") and candidate.is_valid_ip_address():
			detected = candidate
	_complete(request_node, detected)


func _complete(request_node: HTTPRequest, detected: String) -> void:
	if request_node != _request:
		return
	_request = null
	request_node.queue_free()
	address = detected
	loading = false
	if not address.is_empty():
		_last_success_msec = Time.get_ticks_msec()
	changed.emit()


func _exit_tree() -> void:
	if _request != null:
		_request.cancel_request()
