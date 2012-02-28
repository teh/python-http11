# What is it

This is a hacky, unfinished python binding for mongrel2's ragel-powered parser. The parser is a "push" state machine instead of a "pull" parser. That  means instead of blokcing on a `read` you can push bytes into the parser and it will return immediately. After pushing in bytes you can query the error and finished states and act accordingly.

# Example

import http11

```python
q = """\
GET /echo HTTP/1.1\r
User-Agent: curl/7.21.0\r
Host: www.local:7999\r
Accept: */*\r
\r
"""

parser = http11.HttpParser()
parser.execute(q, len(q))
print parser.is_finished(), parser.has_error()
print parser.headers
print parser.method, parser.path, parser.version

# 1 0
# {'host': 'www.local:7999', 'accept': '*/*', 'user-agent': 'curl/7.21.0'}
# GET /echo HTTP/1.1
```

# Licence

This is mostly mongrel2 stuff, so those bits are BSD. Any additional code is BSD as well.
