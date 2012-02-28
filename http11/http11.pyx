cimport cpython.buffer as pybuffer
cimport cpython.string as pystring

cdef extern from "stdlib.h":
       void *malloc(size_t size)
       void free(void *ptr)
    
cdef extern from "http11_common.h":
    ctypedef void (*element_cb)(void* data, char *at, size_t length)
    ctypedef void (*field_cb)(void* data, char *field, size_t flen, char *value, size_t vlen)

cdef extern from "http11_parser.h":
    ctypedef struct http_parser:
        size_t body_start
        int content_len
        field_cb http_field
        element_cb request_method
        element_cb request_uri
        element_cb fragment
        element_cb request_path
        element_cb query_string
        element_cb http_version
        element_cb header_done
        void* data

    int http_parser_init(http_parser *parser)
    int http_parser_finish(http_parser *parser)
    size_t http_parser_execute(http_parser *parser, char *data, size_t len, size_t off)
    int http_parser_has_error(http_parser *parser)
    int http_parser_is_finished(http_parser *parser)

cdef extern from "httpclient_parser.h":
    ctypedef struct httpclient_parser:
        size_t body_start
        int content_len
        int status
        int chunked
        int close

        field_cb http_field
        element_cb reason_phrase
        element_cb status_code
        element_cb chunk_size
        element_cb http_version
        element_cb header_done 
        element_cb last_chunk
        void* data

        int httpclient_parser_init(httpclient_parser *parser)
        int httpclient_parser_finish(httpclient_parser *parser)
        int httpclient_parser_execute(httpclient_parser *parser, char *data, size_t len, size_t off)
        int httpclient_parser_has_error(httpclient_parser *parser)
        int httpclient_parser_is_finished(httpclient_parser *parser)

cdef class HttpClientParser:
    cdef httpclient_parser* _parser
    cdef public object request
    cdef public object headers
    cdef readonly int status

    cdef void http_field(self, char *field, size_t flen, char *value, size_t vlen):
        k = pystring.PyString_FromStringAndSize(field, flen)
        v = pystring.PyString_FromStringAndSize(value, vlen)
        self.headers[k.lower()] = v

    cdef reason_phrase(self, char* at, size_t length):
           pystring.PyString_FromStringAndSize(at, length)
           
    cdef status_code(self, char* at, size_t length):
           pystring.PyString_FromStringAndSize(at, length)

    cdef chunk_size(self, char* at, size_t length):
           pystring.PyString_FromStringAndSize(at, length)

    cdef http_version(self, char* at, size_t length):
           pystring.PyString_FromStringAndSize(at, length)

    cdef header_done(self, char* at, size_t length):
           pystring.PyString_FromStringAndSize(at, length)

    cdef last_chunk(self, char* at, size_t length):
           pystring.PyString_FromStringAndSize(at, length)

    def __cinit__(self):
        self.offset = 0
        self._parser = <httpclient_parser*>malloc(sizeof(httpclient_parser))
        self._parser.http_field = <field_cb>self.http_field
        self.request = {}
        self.headers = {}

cdef class HttpParser:
    cdef http_parser* _parser
    cdef size_t offset
    cdef public object headers
    cdef readonly unsigned int body_start
    cdef readonly unsigned int content_length
    cdef readonly object method
    cdef readonly object uri
    cdef readonly object fragment
    cdef readonly object path
    cdef readonly object query
    cdef readonly object version

    cdef void http_field_cb(self, char *field, size_t flen, char *value, size_t vlen):
        k = pystring.PyString_FromStringAndSize(field, flen)
        v = pystring.PyString_FromStringAndSize(value, vlen)
        self.headers[k.lower()] = v

    cdef void request_method_cb(self, char* at, size_t length):
        self.method = pystring.PyString_FromStringAndSize(at, length).upper()

    cdef void request_uri_cb(self, char* at, size_t length):
        self.uri = pystring.PyString_FromStringAndSize(at, length)

    cdef void fragment_cb(self, char* at, size_t length):
        self.fragment = pystring.PyString_FromStringAndSize(at, length)

    cdef void request_path_cb(self, char* at, size_t length):
        self.path = pystring.PyString_FromStringAndSize(at, length)

    cdef void query_string_cb(self, char* at, size_t length):
        self.query = pystring.PyString_FromStringAndSize(at, length)

    cdef void http_version_cb(self, char* at, size_t length):
        self.version = pystring.PyString_FromStringAndSize(at, length)

    cdef void header_done_cb(self, char* at, size_t length):
        self.content_length = self._parser.content_len
        self.body_start = self._parser.body_start

    def __cinit__(self):
        self.offset = 0
        self._parser = <http_parser*>malloc(sizeof(http_parser))
        http_parser_init(self._parser)
        self._parser.http_field = <field_cb>self.http_field_cb
        self._parser.request_method = <element_cb>self.request_method_cb
        self._parser.request_uri = <element_cb>self.request_uri_cb
        self._parser.fragment = <element_cb>self.fragment_cb
        self._parser.request_path = <element_cb>self.request_path_cb
        self._parser.query_string = <element_cb>self.query_string_cb
        self._parser.http_version = <element_cb>self.http_version_cb
        self._parser.header_done = <element_cb>self.header_done_cb
        self._parser.data = <void*>self
        self.headers = {}

    cpdef execute(self, object buffer_, int length):
        cdef pybuffer.Py_buffer view
        pybuffer.PyObject_GetBuffer(buffer_, &view, 0)
        http_parser_execute(self._parser, <char*>view.buf, length, self.offset)
        self.offset = length
        pybuffer.PyBuffer_Release(&view)

    cpdef has_error(self):
        return http_parser_has_error(self._parser)

    cpdef is_finished(self):
        return http_parser_is_finished(self._parser)

    def __dealloc__(self):
        if self._parser is not NULL:
            free(<void*>self._parser)
            self._parser = NULL
