import socket
import eventlet
import http11

class InvalidRequest(Exception): pass

def pipe(in_, out_):
    while True:
        d = in_.recv(2**10)
        if d == '':
            break
        out_.sendall(d)

def connect_backend(headers):
    pass

def handler(sock, parser, body_start):
#    print parser.method, parser.uri, parser.fragment, parser.path, parser.query, parser.version
    if parser.headers.get('expect') == '100-continue':
        sock.sendall('HTTP/1.1 100 Continue\r\n\r\n')

    # From here on we send a cleaned up request on to the correct
    # client and, after establishing the connection, pipe
    # bidirectionally.
    backend_sock, response = connect_backend(headers)
    backend_sock.sendall(body_start)

    if len(body_start) < int(headers.get('content-length', 0)):
        eventlet.spawn_n(pipe(sock, backend_sock))

    pipe(backend_sock, sock)

    try:
        sock.shutdown(socket.SHUT_RDWR)
    except socket.error:
        pass

def handle_internal(sock):
    parser = http11.HttpParser()
    buf = bytearray(2**14)
    length, offset = 0, 0

    while True:
        d = sock.recv(2**10)
        length += len(d)
        if not d:
            return
        buf[offset:length] = d
        parser.execute(buf, length)

        if parser.has_error():
            raise InvalidRequest()

        if not parser.has_error() and parser.is_finished():
            break
        offset = length
    body_start = buf[parser.body_start:length]
    handler(sock, parser, body_start)

l = eventlet.listen(('127.0.0.1', 5000), backlog=50)
while True:
    sock, _ = l.accept()
    handle_internal(sock)
