import eventlet
from eventlet.green import socket
import http11

class InvalidRequest(Exception): pass

def pipe(in_, out_):
    while True:
        d = in_.recv(2**13)
        if d == '':
            break
        out_.sendall(d)


def connect_backend(sock, backend_sock, parser):
    request = ['{} {} HTTP/1.0'.format(parser.method, parser.uri)]
    for k, v in parser.headers.items():
        request.append('{}: {}'.format(k, v))
    request.append('\r\n')
    backend_sock.sendall('\r\n'.join(request))

def handle_rest(sock, backend_sock, parser, body_start):
#    print parser.method, parser.uri, parser.fragment, parser.path, parser.query, parser.version
    if parser.headers.get('expect') == '100-continue':
        sock.sendall('HTTP/1.1 100 Continue\r\n\r\n')

    # From here on we send a cleaned up request on to the correct
    # client and, after establishing the connection, pipe
    # bidirectionally.
    connect_backend(sock, backend_sock, parser)
    if body_start:
        backend_sock.sendall(body_start)

    if len(body_start) < int(parser.headers.get('content-length', 0)):
        eventlet.spawn_n(pipe(sock, backend_sock))

    pipe(backend_sock, sock)
    try:
        backend_sock.shutdown(socket.SHUT_RDWR)
    except socket.error:
        pass
    try:
        sock.shutdown(socket.SHUT_RDWR)
    except socket.error:
        pass

def handle_header(sock, from_):
    parser = http11.HttpParser()
    buf = bytearray(2**14)
    length, offset = 0, 0

    while True:
        d = sock.recv(2**12)
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
    parser.headers.update(remote=from_)
    return parser, body_start

def handle(sock, from_):
    parser, body_start = handle_header(sock, from_)

    backend_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    backend_sock.connect(('127.0.0.1', 8000))

    handle_rest(sock, backend_sock, parser, body_start)

def serve(listen_sock):
    while True:
        sock, from_ = listen_sock.accept()
        eventlet.spawn_n(handle, sock, from_)

if __name__ == '__main__':
    l = eventlet.listen(('127.0.0.1', 5000), backlog=50)
    serve(l)
    
