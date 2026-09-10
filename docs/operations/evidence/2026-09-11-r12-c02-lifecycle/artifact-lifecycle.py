from pathlib import Path
import ctypes as c
import hashlib, json, socket, struct, threading, time

root = Path(__file__).parent
dll = root / 'windows-a/pokrov-core.dll'
assert dll.read_bytes() == (root / 'windows-b/pokrov-core.dll').read_bytes()
fixture = root / 'artifact-loopback-fixture'
fixture.mkdir()
for name in ('base', 'working', 'temp'):
    (fixture / name).mkdir()
(fixture / 'working/data').mkdir()
lib = c.CDLL(str(dll))
lib.freeString.argtypes = [c.c_void_p]
lib.freeString.restype = None
lib.setup.argtypes = [c.c_char_p] * 3 + [c.c_int] + [c.c_char_p] * 2 + [c.c_longlong, c.c_bool]
lib.setup.restype = c.c_void_p
for name in ('start', 'restart'):
    getattr(lib, name).argtypes = [c.c_char_p, c.c_bool]
    getattr(lib, name).restype = c.c_void_p
lib.stop.argtypes = []
lib.stop.restype = c.c_void_p

def result(fn, *args):
    pointer = fn(*args)
    if not pointer:
        return b''
    raw = c.string_at(pointer)
    lib.freeString(pointer)
    return raw

assert not result(lib.setup, *[str(fixture / name).encode() for name in ('base', 'working', 'temp')], 0, b'', b'', 0, False)
origin = socket.socket()
origin.bind(('127.0.0.1', 0))
origin.listen()

def echo(connection):
    with connection:
        while data := connection.recv(32):
            connection.sendall(data)

def accept():
    while True:
        try:
            connection, _ = origin.accept()
        except OSError:
            return
        threading.Thread(target=echo, args=(connection,), daemon=True).start()

threading.Thread(target=accept, daemon=True).start()
with socket.socket() as reservation:
    reservation.bind(('127.0.0.1', 0))
    port = reservation.getsockname()[1]
profile = fixture / 'profile.json'
profile.write_text(json.dumps({'log': {'disabled': True}, 'inbounds': [{'type': 'mixed', 'listen': '127.0.0.1', 'listen_port': port}], 'outbounds': [{'type': 'direct', 'tag': 'direct'}], 'route': {'final': 'direct'}}), encoding='utf8')

def read_exact(sock, length):
    data = b''
    while len(data) < length:
        chunk = sock.recv(length - len(data))
        assert chunk, 'unexpected SOCKS EOF'
        data += chunk
    return data

def connect():
    sock = socket.create_connection(('127.0.0.1', port), timeout=2)
    sock.sendall(b'\x05\x01\x00')
    assert read_exact(sock, 2) == b'\x05\x00'
    sock.sendall(b'\x05\x01\x00\x01' + socket.inet_aton('127.0.0.1') + struct.pack('!H', origin.getsockname()[1]))
    response = read_exact(sock, 4)
    assert response[:2] == b'\x05\x00'
    if response[3] == 1:
        read_exact(sock, 6)
    elif response[3] == 4:
        read_exact(sock, 18)
    else:
        read_exact(sock, read_exact(sock, 1)[0] + 2)
    sock.sendall(b'C02')
    assert read_exact(sock, 3) == b'C02'
    return sock

def cancelled(sock):
    try:
        try:
            assert sock.recv(1) == b'', 'session remained readable after shutdown'
        except ConnectionResetError:
            pass
    finally:
        sock.close()

get_count = c.WinDLL('kernel32', use_last_error=True).GetProcessHandleCount
get_count.argtypes = [c.c_void_p, c.POINTER(c.c_ulong)]
get_count.restype = c.c_int
def handles():
    value = c.c_ulong()
    assert get_count(c.c_void_p(-1), c.byref(value))
    return value.value

samples = []
for index in range(100):
    assert not result(lib.start, str(profile).encode(), True), 'start failed'
    old = connect()
    assert not result(lib.restart, str(profile).encode(), True), 'restart failed'
    cancelled(old)
    new = connect()
    assert not result(lib.stop), 'stop failed'
    cancelled(new)
    time.sleep(0.02)
    samples.append({'cycle': index + 1, 'handles': handles()})
time.sleep(1)
final = handles()
last = [x['handles'] for x in samples[-20:]]
receipt = {'status': 'PASS_BOUNDED' if max(last) - min(last) <= 2 and final <= max(last) else 'FAIL_RESOURCE_STABILITY', 'dll_sha256': hashlib.sha256(dll.read_bytes()).hexdigest(), 'scheduler': 'Go default; GOMAXPROCS unset', 'cycles': 100, 'start_restart_stop': True, 'loopback_sessions_cancelled': 200, 'network_scope': '127.0.0.1 only; no TUN or host route changes', 'samples': samples, 'last_twenty_handle_range': [min(last), max(last)], 'final_handles': final, 'goroutine_measurement': 'not exported by ABI; covered by separate source race test'}
(root / 'artifact-lifecycle.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf8')
origin.close()
assert receipt['status'] == 'PASS_BOUNDED', receipt['status']
print(json.dumps({k: v for k, v in receipt.items() if k != 'samples'}))
