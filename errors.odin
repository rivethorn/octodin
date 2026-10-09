package github

import "core:fmt"
import "core:strings"

// Api_Error describes a non-2xx response from the GitHub API.
Api_Error :: struct {
	status:            int,
	message:           string,
	documentation_url: string,
}

// destroy_api_error releases an Api_Error.
destroy_api_error :: proc(e: ^Api_Error) {
	delete(e.message)
	delete(e.documentation_url)
	e^ = {}
}

// Transport_Error describes a failure below HTTP: libcurl could not
// complete the request (DNS, TLS, timeout, connection refused, ...).
Transport_Error :: struct {
	code:    int,
	message: string,
}

// Codec_Error describes a failure to encode a request payload or decode
// a successful response body as JSON.
Codec_Error :: struct {
	message: string,
}

// Error is the failure type returned by every request procedure.
Error :: union {
	Transport_Error,
	Api_Error,
	Codec_Error,
}

// error_message renders a human-readable, single-line description.
error_message :: proc(err: Error, allocator := context.allocator) -> string {
	switch e in err {
	case Transport_Error:
		return strings.clone(e.message, allocator)
	case Api_Error:
		return strings.concatenate(
			{
				"github: HTTP ",
				_status_string(e.status, allocator),
				": ",
				e.message,
			},
			allocator,
		)
	case Codec_Error:
		return strings.clone(e.message, allocator)
	}
	return strings.clone("github: unknown error", allocator)
}

// destroy_error releases any heap state held by an Error value.
destroy_error :: proc(err: ^Error) {
	switch &e in err {
	case Transport_Error:
		delete(e.message)
	case Api_Error:
		destroy_api_error(&e)
	case Codec_Error:
		delete(e.message)
	}
	err^ = nil
}

// error_status returns the HTTP status for API errors, or 0 otherwise.
error_status :: proc(err: Error) -> int {
	if e, ok := err.(Api_Error); ok {
		return e.status
	}
	return 0
}

// is_not_found reports whether err is a 404 from the API.
is_not_found :: proc(err: Error) -> bool {
	return error_status(err) == 404
}

// is_rate_limited reports whether err is a 403/429 that carries a
// rate-limit-exceeded message.
is_rate_limited :: proc(err: Error) -> bool {
	e, ok := err.(Api_Error)
	if !ok {
		return false
	}
	if e.status != 403 && e.status != 429 {
		return false
	}
	return strings.contains(
		strings.to_lower(e.message, context.temp_allocator),
		"rate limit",
	)
}

// is_unauthorized reports whether err is a 401 from the API.
is_unauthorized :: proc(err: Error) -> bool {
	return error_status(err) == 401
}

_status_string :: proc(status: int, allocator := context.allocator) -> string {
	return fmt.aprintf("%d", status, allocator = allocator)
}
