extends Node
var cid = 0
var client = WebSocketClient.new()
var last_status = -1
var scid
var handshakeRequestId
var callbackList = {}

signal message_received

func _ready():
  # Set events
  client.connect("connection_established", self, "_connection_established")
  client.connect("server_close_request", self, "_server_close_request")
  client.connect("connection_error", self, "_connection_error")
  client.connect("connection_closed", self, "_connection_closed")
  client.connect("data_received", self, "_data_received")
  set_process(true)
  start("ws://127.0.0.1:8000/socketcluster/")

func _process(delta):
  var status = client.get_connection_status()

  if status != last_status:
    last_status = status
    if status == WebSocketClient.CONNECTION_DISCONNECTED:
      print("disconnected")
    else:
      print(status)

  if status != WebSocketClient.CONNECTION_DISCONNECTED:
    client.poll()

func start(server):
  # Connect to server
  print("connecting...")
  client.set_verify_ssl_enabled(false)
  client.connect_to_url(server, PoolStringArray([]), false)

func saveAuthId(event, data):
  print("assigned id ", data.id)
  scid = data.id

func _connection_established(protocol):
  print("success!")
  requestResponse("#handshake", {}, funcref(self, "saveAuthId"))

func requestResponse(event, data, f):
  var c = str(writeMessage(event, data))
  callbackList[c] = f
  return c

func writeMessage(event, data):
  cid = cid + 1
  var o = {
    "event": event,
    "data": data,
    "cid": cid 
  }
  write(to_json(o).to_utf8())
  return cid

func _server_close_request(code, reason):
  print("_server_close_request", reason)

func _connection_error():
  var err = client.get_packet_error()
  print("error", err)

func _data_received(pid=1):
  # Read message
  var peer = client.get_peer(1)
  var pkt = peer.get_packet()
  var mesg = pkt.get_string_from_utf8()
  if mesg == "#1":
    print("PONG!")
    write("#2".to_ascii())
  elif mesg == "1":
    print("PONG")
    write("1".to_ascii());
  else:
    var m = JSON.parse(mesg);
    var event = m.result.get("event")
    var rid = m.result.get("rid")
    var data = m.result.get("data")
    if rid != null:
      var r = str(rid)
      print("rmsg", r, callbackList[r] != null)
      if callbackList[r] != null:
        callbackList[r].call_func(event, data)
        callbackList.erase(r)
    emit_signal("message_received", event, data, rid)

func write(data):
  # Send message
  var peer = client.get_peer(1)
  peer.put_packet(data)
