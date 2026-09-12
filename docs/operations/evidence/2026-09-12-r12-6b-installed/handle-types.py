import ctypes as c
import struct
from collections import Counter

nt = c.WinDLL('ntdll')
query = nt.NtQueryInformationProcess
query.argtypes = [c.c_void_p, c.c_ulong, c.c_void_p, c.c_ulong, c.POINTER(c.c_ulong)]
query.restype = c.c_long
query_object = nt.NtQueryObject
query_object.argtypes = [c.c_void_p, c.c_ulong, c.c_void_p, c.c_ulong, c.POINTER(c.c_ulong)]
query_object.restype = c.c_long
names = {}

def handle_types():
    buffer = c.create_string_buffer(1024 * 1024)
    used = c.c_ulong()
    assert query(c.c_void_p(-1), 51, buffer, len(buffer), c.byref(used)) == 0
    count = struct.unpack_from('<Q', buffer)[0]
    types = Counter()
    for index in range(count):
        offset = 16 + index * 40
        handle = struct.unpack_from('<Q', buffer, offset)[0]
        kind = struct.unpack_from('<I', buffer, offset + 28)[0]
        if kind not in names:
            info = c.create_string_buffer(4096)
            if query_object(handle, 2, info, len(info), c.byref(used)) == 0:
                length = struct.unpack_from('<H', info)[0]
                pointer = struct.unpack_from('<Q', info, 8)[0]
                assert c.addressof(info) <= pointer < c.addressof(info) + len(info)
                names[kind] = c.wstring_at(pointer, length // 2)
        types[names.get(kind, str(kind))] += 1
    return dict(types)
