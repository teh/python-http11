import socket
import eventlet
import http11

def handle(sock):
    p = http11.HttpParser()
    buf = bytearray(2**14)
    length, offset = 0, 0

    while True:
        d = sock.recv(2**10)
        length += len(d)
        if not d:
            return
        buf[offset:length] = d
        p.execute(buf, length)
        offset = length
        if not p.has_error() and p.is_finished():
            break

#    print p.request, p.headers
    sock.sendall('HTTP/1.1 200 OK\r\nContent-length: 0\r\n\r\n')
    try:
        sock.shutdown(socket.SHUT_RDWR)
    except socket.error:
        pass


l = eventlet.listen(('127.0.0.1', 5000), backlog=50)
while True:
    sock, _ = l.accept()
    handle(sock)
