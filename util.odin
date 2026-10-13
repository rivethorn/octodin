package octodin

import "core:encoding/json"
import "core:fmt"
import "core:strconv"
import "core:strings"

// url_escape percent-encodes s for use in a path segment or query value.
// Unreserved characters (RFC 3986) pass through untouched.
url_escape :: proc(s: string, allocator := context.allocator) -> string {
	b := strings.builder_make(allocator)
	for i := 0; i < len(s); i += 1 {
		ch := s[i]
		switch {
		case ch >= 'A' &&
		     ch <= 'Z',
		     ch >= 'a' &&
		     ch <= 'z',
		     ch >= '0' &&
		     ch <= '9',
		     ch == '-' ||
		     ch == '_' ||
		     ch == '.' ||
		     ch == '~':
			strings.write_byte(&b, ch)
		case:
			strings.write_string(&b, "%")
			hex := "0123456789ABCDEF"
			strings.write_byte(&b, hex[ch >> 4])
			strings.write_byte(&b, hex[ch & 0x0F])
		}
	}
	return strings.to_string(b)
}

// Query_Builder accumulates URL query parameters.
Query_Builder :: struct {
	params: [dynamic]string,
}

// query_builder_make creates an empty Query_Builder.
query_builder_make :: proc(allocator := context.allocator) -> Query_Builder {
	return Query_Builder{params = make([dynamic]string, allocator = allocator)}
}

// query_builder_destroy releases a Query_Builder.
query_builder_destroy :: proc(q: ^Query_Builder) {
	for p in q.params {
		delete(p)
	}
	delete(q.params)
	q^ = {}
}

// query_add_string appends key=value, skipping empty values.
query_add_string :: proc(
	q: ^Query_Builder,
	key, value: string,
	allocator := context.allocator,
) {
	if value == "" {
		return
	}
	append(
		&q.params,
		strings.concatenate(
			{key, "=", url_escape(value, allocator)},
			allocator,
		),
	)
}

// query_add_int appends key=value, skipping zero values.
query_add_int :: proc(
	q: ^Query_Builder,
	key: string,
	value: int,
	allocator := context.allocator,
) {
	if value == 0 {
		return
	}
	append(
		&q.params,
		strings.concatenate(
			{key, "=", _itoa(value, context.temp_allocator)},
			allocator,
		),
	)
}

// query_add_bool appends key=true/false unconditionally.
query_add_bool :: proc(
	q: ^Query_Builder,
	key: string,
	value: bool,
	allocator := context.allocator,
) {
	append(
		&q.params,
		strings.concatenate(
			{key, "=", "true" if value else "false"},
			allocator,
		),
	)
}

// query_encode renders "?k=v&..." or "" when empty. The caller owns the result.
query_encode :: proc(
	q: ^Query_Builder,
	allocator := context.allocator,
) -> string {
	if len(q.params) == 0 {
		return ""
	}
	return strings.concatenate(
		{"?", strings.join(q.params[:], "&", allocator)},
		allocator,
	)
}

// with_query appends an encoded query to a path. The caller owns the result.
with_query :: proc(
	path: string,
	q: ^Query_Builder,
	allocator := context.allocator,
) -> string {
	return strings.concatenate({path, query_encode(q, allocator)}, allocator)
}


// --- internal formatting helpers ---

@(private)
_itoa :: proc(n: int, allocator := context.allocator) -> string {
	return fmt.aprintf("%d", n, allocator = allocator)
}

@(private)
_atoi :: proc(s: string) -> (int, bool) {
	return strconv.parse_int(s, 10)
}

@(private)
_unmarshal_error_string :: proc(err: json.Unmarshal_Error) -> string {
	// Rendered on the temp allocator; callers clone what they keep.
	return fmt.tprintf("%v", err)
}

@(private)
_marshal_error_string :: proc(err: json.Marshal_Error) -> string {
	return fmt.tprintf("%v", err)
}
