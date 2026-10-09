package github

import "base:runtime"
import c_libc "core:c/libc"
import "core:encoding/json"
import "core:mem"
import "core:strings"
import "core:sync"
import curl "vendor:curl"

// Method is an HTTP verb understood by do_request.
Method :: enum {
	Get,
	Post,
	Put,
	Patch,
	Delete,
	Head,
}

// Response is the outcome of a single API request.
//
// The caller owns body and headers and must call response_destroy.
// On typed helpers (get_into, send_json, ...) the Response is still
// returned alongside the decoded value so callers can inspect status,
// headers, and rate-limit state.
Response :: struct {
	status:  int,
	body:    []u8,
	headers: map[string]string,
	rate:    Rate_Limit,
}

// response_destroy releases the body and headers owned by a Response.
response_destroy :: proc(r: ^Response) {
	if r == nil {
		return
	}
	delete(r.body)
	for k, v in r.headers {
		delete(k)
		delete(v)
	}
	delete(r.headers)
	r^ = {}
}

// do_request performs one HTTP request against path (which must start
// with "/" and may contain a query string) and returns the raw Response.
// A nil body sends no payload. Non-2xx statuses come back as Api_Error.
//
// path may also be an absolute URL (starting with "http"), in which case
// it is used as-is. This supports upload endpoints such as
// uploads.github.com as well as following pagination links directly.
//
// content_type overrides the request body MIME type; it defaults to
// "application/json" whenever a body is present.
do_request :: proc(
	c: ^Client,
	method: Method,
	path: string,
	body: []u8 = nil,
	content_type: string = "",
) -> (
	resp: Response,
	err: Error,
) {
	context.allocator = c.allocator
	_ensure_curl_init()

	handle := curl.easy_init()
	if handle == nil {
		return {}, Transport_Error{code = -1, message = strings.clone("github: curl_easy_init failed", c.allocator)}
	}
	defer curl.easy_cleanup(handle)

	url :=
		path if strings.has_prefix(path, "http") else strings.concatenate({c.base_url, path}, c.allocator)
	defer delete(url)
	url_c := strings.clone_to_cstring(url, c.allocator)
	defer delete(url_c)

	if rc := curl.easy_setopt(handle, .URL, url_c); rc != .E_OK {
		return {}, _transport_error(rc, "set URL")
	}
	if rc := curl.easy_setopt(handle, .USERAGENT, c.user_agent); rc != .E_OK {
		return {}, _transport_error(rc, "set user agent")
	}
	if rc := curl.easy_setopt(handle, .TIMEOUT, c_libc.long(c.timeout_s));
	   rc != .E_OK {
		return {}, _transport_error(rc, "set timeout")
	}
	if rc := curl.easy_setopt(handle, .FOLLOWLOCATION, c_libc.long(1));
	   rc != .E_OK {
		return {}, _transport_error(rc, "set redirect policy")
	}

	body_buf := _Curl_Buffer {
		ctx = context,
	}
	defer delete(body_buf.data)
	header_buf := _Curl_Buffer {
		ctx = context,
	}
	defer delete(header_buf.data)

	if rc := curl.easy_setopt(handle, .WRITEFUNCTION, _write_cb); rc != .E_OK {
		return {}, _transport_error(rc, "set write callback")
	}
	if rc := curl.easy_setopt(handle, .WRITEDATA, &body_buf); rc != .E_OK {
		return {}, _transport_error(rc, "set write target")
	}
	if rc := curl.easy_setopt(handle, .HEADERFUNCTION, _write_cb);
	   rc != .E_OK {
		return {}, _transport_error(rc, "set header callback")
	}
	if rc := curl.easy_setopt(handle, .HEADERDATA, &header_buf); rc != .E_OK {
		return {}, _transport_error(rc, "set header target")
	}

	// Method + payload.
	switch method {
	case .Get:
		if rc := curl.easy_setopt(handle, .HTTPGET, c_libc.long(1));
		   rc != .E_OK {
			return {}, _transport_error(rc, "set GET")
		}
	case .Post:
		if rc := curl.easy_setopt(handle, .POST, c_libc.long(1)); rc != .E_OK {
			return {}, _transport_error(rc, "set POST")
		}
		if len(body) > 0 {
			_set_payload(handle, body) or_return
		}
	case .Put, .Patch, .Delete:
		verb: cstring =
			"PUT" if method == .Put else ("PATCH" if method == .Patch else "DELETE")
		if rc := curl.easy_setopt(handle, .CUSTOMREQUEST, verb); rc != .E_OK {
			return {}, _transport_error(rc, "set custom verb")
		}
		if len(body) > 0 {
			_set_payload(handle, body) or_return
		}
	case .Head:
		if rc := curl.easy_setopt(handle, .NOBODY, c_libc.long(1));
		   rc != .E_OK {
			return {}, _transport_error(rc, "set HEAD")
		}
	}

	// Headers. Every cstring below must outlive easy_perform.
	hdrs: ^curl.slist = nil
	defer curl.slist_free_all(hdrs)
	header_strings := make([dynamic]string, allocator = c.allocator)
	defer {
		for s in header_strings {
			delete(s)
		}
		delete(header_strings)
	}
	header_cstrings := make([dynamic]cstring, allocator = c.allocator)
	defer {
		for s in header_cstrings {
			delete(s)
		}
		delete(header_cstrings)
	}

	_add_header :: proc(
		hdrs: ^^curl.slist,
		owned: ^[dynamic]string,
		cstrs: ^[dynamic]cstring,
		alloc: mem.Allocator,
		line: string,
	) {
		append(owned, strings.clone(line, alloc))
		cs := strings.clone_to_cstring(owned[len(owned) - 1], alloc)
		append(cstrs, cs)
		hdrs^ = curl.slist_append(hdrs^, cs)
	}

	_add_header(
		&hdrs,
		&header_strings,
		&header_cstrings,
		c.allocator,
		"Accept: application/vnd.github+json",
	)
	{
		line := strings.concatenate(
			{"X-GitHub-Api-Version: ", c.api_version},
			c.allocator,
		)
		defer delete(line)
		_add_header(
			&hdrs,
			&header_strings,
			&header_cstrings,
			c.allocator,
			line,
		)
	}
	if len(c.token) > 0 {
		line := strings.concatenate(
			{"Authorization: Bearer ", c.token},
			c.allocator,
		)
		defer delete(line)
		_add_header(
			&hdrs,
			&header_strings,
			&header_cstrings,
			c.allocator,
			line,
		)
	}
	if len(body) > 0 {
		ct := content_type if content_type != "" else "application/json"
		line := strings.concatenate({"Content-Type: ", ct}, c.allocator)
		defer delete(line)
		_add_header(
			&hdrs,
			&header_strings,
			&header_cstrings,
			c.allocator,
			line,
		)
	}
	if rc := curl.easy_setopt(handle, .HTTPHEADER, hdrs); rc != .E_OK {
		return {}, _transport_error(rc, "set headers")
	}

	if rc := curl.easy_perform(handle); rc != .E_OK {
		msg := string(curl.easy_strerror(rc))
		return {}, Transport_Error{code = int(rc), message = strings.concatenate({"github: request failed: ", msg}, c.allocator)}
	}

	code: c_libc.long
	curl.easy_getinfo(handle, .RESPONSE_CODE, &code)

	headers, rate := _parse_response_headers(header_buf.data[:], c.allocator)
	resp_body := make([]u8, len(body_buf.data), c.allocator)
	copy(resp_body, body_buf.data[:])
	resp = Response {
		status  = int(code),
		body    = resp_body,
		headers = headers,
		rate    = rate,
	}

	if resp.status < 200 || resp.status >= 300 {
		defer response_destroy(&resp)
		return {}, _api_error_from_body(resp.status, resp.body, c.allocator)
	}
	return resp, nil
}

// get performs a GET request and returns the raw Response.
get :: proc(c: ^Client, path: string) -> (Response, Error) {
	return do_request(c, .Get, path)
}

// post_raw performs a POST with a pre-encoded payload.
post_raw :: proc(
	c: ^Client,
	path: string,
	body: []u8 = nil,
	content_type: string = "",
) -> (
	Response,
	Error,
) {
	return do_request(c, .Post, path, body, content_type)
}

// put_raw performs a PUT with a pre-encoded payload.
put_raw :: proc(
	c: ^Client,
	path: string,
	body: []u8 = nil,
	content_type: string = "",
) -> (
	Response,
	Error,
) {
	return do_request(c, .Put, path, body, content_type)
}

// patch_raw performs a PATCH with a pre-encoded payload.
patch_raw :: proc(
	c: ^Client,
	path: string,
	body: []u8 = nil,
	content_type: string = "",
) -> (
	Response,
	Error,
) {
	return do_request(c, .Patch, path, body, content_type)
}

// del performs a DELETE request and returns the raw Response.
del :: proc(c: ^Client, path: string, body: []u8 = nil) -> (Response, Error) {
	return do_request(c, .Delete, path, body)
}

// decode_body unmarshals resp.body into a fresh T allocated with the
// client's allocator. The Response stays owned by the caller.
decode_body :: proc(
	resp: Response,
	$T: typeid,
	allocator := context.allocator,
) -> (
	T,
	Error,
) {
	v: T
	if len(resp.body) == 0 {
		return v, nil
	}
	if uerr := json.unmarshal(resp.body, &v, allocator = allocator);
	   uerr != nil {
		msg := strings.concatenate(
			{
				"github: failed to decode response: ",
				_unmarshal_error_string(uerr),
			},
			allocator,
		)
		return v, Codec_Error{message = msg}
	}
	return v, nil
}

// get_into performs a GET request and decodes the JSON body into T.
// The returned Response always stays owned by the caller, even when
// decoding fails — destroy it with response_destroy in all cases.
get_into :: proc(
	c: ^Client,
	path: string,
	$T: typeid,
) -> (
	v: T,
	resp: Response,
	err: Error,
) {
	resp, err = do_request(c, .Get, path)
	if err != nil {
		return {}, {}, err
	}
	decoded, derr := decode_body(resp, T, c.allocator)
	if derr != nil {
		return {}, resp, derr
	}
	return decoded, resp, nil
}

// send_json marshals payload to JSON, sends it with method, and decodes
// the JSON response into Out. The Response stays owned by the caller.
send_json :: proc(
	c: ^Client,
	method: Method,
	path: string,
	payload: $In,
	$Out: typeid,
) -> (
	out: Out,
	resp: Response,
	err: Error,
) {
	context.allocator = c.allocator
	data, merr := json.marshal(payload, allocator = c.allocator)
	if merr != nil {
		msg := strings.concatenate(
			{
				"github: failed to encode request: ",
				_marshal_error_string(merr),
			},
			c.allocator,
		)
		return {}, {}, Codec_Error{message = msg}
	}
	defer delete(data)

	resp, err = do_request(c, method, path, data)
	if err != nil {
		return {}, {}, err
	}
	decoded, derr := decode_body(resp, Out, c.allocator)
	if derr != nil {
		return {}, resp, derr
	}
	return decoded, resp, nil
}

// send_json_noresponse marshals payload to JSON and sends it, discarding
// any success body. Useful for 204 No Content endpoints.
send_json_noresponse :: proc(
	c: ^Client,
	method: Method,
	path: string,
	payload: $In,
) -> (
	resp: Response,
	err: Error,
) {
	context.allocator = c.allocator
	data, merr := json.marshal(payload, allocator = c.allocator)
	if merr != nil {
		msg := strings.concatenate(
			{
				"github: failed to encode request: ",
				_marshal_error_string(merr),
			},
			c.allocator,
		)
		return {}, Codec_Error{message = msg}
	}
	defer delete(data)
	return do_request(c, method, path, data)
}


// --- internals ---

@(private)
_Curl_Buffer :: struct {
	data: [dynamic]u8,
	ctx:  runtime.Context,
}

@(private)
_write_cb :: proc "c" (
	ptr: rawptr,
	size: c_libc.size_t,
	nmemb: c_libc.size_t,
	userdata: rawptr,
) -> c_libc.size_t {
	buf := (^_Curl_Buffer)(userdata)
	context = buf.ctx
	total := int(size * nmemb)
	if total == 0 {
		return 0
	}
	if resize(&buf.data, len(buf.data) + total) != nil {
		return 0
	}
	copy(buf.data[len(buf.data) - total:], ([^]u8)(ptr)[:total])
	return c_libc.size_t(total)
}

@(private)
_curl_init_once: sync.Once

@(private)
_curl_global_init :: proc() {
	curl.global_init(curl.GLOBAL_DEFAULT)
}

@(private)
_ensure_curl_init :: proc() {
	sync.once_do(&_curl_init_once, _curl_global_init)
}

@(private)
_transport_error :: proc(rc: curl.code, op: string) -> Error {
	msg := string(curl.easy_strerror(rc))
	return Transport_Error {
		code = int(rc),
		message = strings.concatenate(
			{"github: curl ", op, " failed: ", msg},
			context.allocator,
		),
	}
}

@(private)
_set_payload :: proc(handle: ^curl.CURL, body: []u8) -> Error {
	if rc := curl.easy_setopt(handle, .POSTFIELDS, raw_data(body));
	   rc != .E_OK {
		return _transport_error(rc, "set payload")
	}
	if rc := curl.easy_setopt(handle, .POSTFIELDSIZE, c_libc.long(len(body)));
	   rc != .E_OK {
		return _transport_error(rc, "set payload size")
	}
	return nil
}

@(private)
_api_error_from_body :: proc(
	status: int,
	body: []u8,
	allocator := context.allocator,
) -> Error {
	msg := ""
	doc := ""
	if len(body) > 0 {
		raw: _Raw_Api_Error
		if json.unmarshal(body, &raw, allocator = context.temp_allocator) ==
		   nil {
			msg = strings.clone(raw.message, allocator)
			doc = strings.clone(raw.documentation_url, allocator)
		}
	}
	if msg == "" {
		msg = strings.concatenate(
			{"request failed with status ", _itoa(status)},
			allocator,
		)
	}
	return Api_Error{status = status, message = msg, documentation_url = doc}
}

@(private)
_Raw_Api_Error :: struct {
	message:           string `json:"message"`,
	documentation_url: string `json:"documentation_url"`,
}

@(private)
_parse_response_headers :: proc(
	raw: []u8,
	allocator := context.allocator,
) -> (
	headers: map[string]string,
	rate: Rate_Limit,
) {
	headers = make(map[string]string, allocator = allocator)
	if len(raw) == 0 {
		return headers, {}
	}
	text := string(raw)
	lines := strings.split_lines(text, context.temp_allocator)
	for line, i in lines {
		if i == 0 || len(strings.trim_space(line)) == 0 {
			continue // status line / terminator
		}
		sep := strings.index(line, ":")
		if sep < 0 {
			continue
		}
		key := strings.to_lower(
			strings.trim_space(line[:sep]),
			context.temp_allocator,
		)
		val := strings.trim_space(line[sep + 1:])
		// Last occurrence wins; header blocks repeat on redirect.
		if prev, ok := headers[key]; ok {
			delete(prev)
		}
		headers[strings.clone(key, allocator)] = strings.clone(val, allocator)
	}
	rate = Rate_Limit {
		limit         = _header_int(headers, "x-ratelimit-limit"),
		remaining     = _header_int(headers, "x-ratelimit-remaining"),
		reset         = _header_int(headers, "x-ratelimit-reset"),
		used          = _header_int(headers, "x-ratelimit-used"),
		retry_after_s = _header_int(headers, "retry-after"),
	}
	return headers, rate
}

@(private)
_header_int :: proc(headers: map[string]string, key: string) -> int {
	v, ok := headers[key]
	if !ok {
		return 0
	}
	n, parsed := _atoi(v)
	if !parsed {
		return 0
	}
	return n
}
