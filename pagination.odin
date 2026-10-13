package octodin

import "core:strings"

// List_Options carries the pagination parameters accepted by nearly
// every "list ..." endpoint.
//
// A zero value lists the first page with the API default page size.
List_Options :: struct {
	// Results per page (max 100). Zero means "API default".
	per_page: int,
	// Page number, 1-based. Zero means "first page".
	page:     int,
	// Cursor-based pagination (some endpoints). Empty means unused.
	after:    string,
	before:   string,
}

// apply_list_options appends per_page/page/after/before to a query builder.
apply_list_options :: proc(
	q: ^Query_Builder,
	opts: List_Options,
	allocator := context.allocator,
) {
	query_add_int(q, "per_page", opts.per_page, allocator)
	query_add_int(q, "page", opts.page, allocator)
	query_add_string(q, "after", opts.after, allocator)
	query_add_string(q, "before", opts.before, allocator)
}

// Page_Info describes where a paginated response sits in the result set,
// parsed from the RFC 5988 Link header.
Page_Info :: struct {
	next:     string,
	prev:     string,
	first:    string,
	last:     string,
	has_next: bool,
	has_prev: bool,
}

// page_info parses pagination links out of a Response.
page_info :: proc(resp: Response) -> Page_Info {
	link, ok := _header_lookup(resp.headers, "link")
	if !ok {
		return {}
	}
	return parse_link_header(link)
}

// parse_link_header parses an RFC 5988 Link header value such as:
//
//	<https://api.github.com/...?page=2>; rel="next", <...>; rel="last"
parse_link_header :: proc(header: string) -> Page_Info {
	info: Page_Info
	for part in strings.split(header, ",", context.temp_allocator) {
		seg := strings.trim_space(part)
		if !strings.has_prefix(seg, "<") {
			continue
		}
		end := strings.index(seg, ">")
		if end < 0 {
			continue
		}
		url := seg[1:end]
		rest := seg[end + 1:]
		rel_key := `rel="`
		at := strings.index(rest, rel_key)
		if at < 0 {
			continue
		}
		name_start := at + len(rel_key)
		name_end := strings.index(rest[name_start:], `"`)
		if name_end < 0 {
			continue
		}
		switch rest[name_start:][:name_end] {
		case "next":
			info.next, info.has_next = url, true
		case "prev":
			info.prev, info.has_prev = url, true
		case "first":
			info.first = url
		case "last":
			info.last = url
		}
	}
	return info
}

// next_page_path extracts the path+query of the next page relative to
// the API base URL, or "" when there is no next page. The caller owns
// the result.
next_page_path :: proc(
	c: ^Client,
	resp: Response,
	allocator := context.allocator,
) -> string {
	info := page_info(resp)
	if !info.has_next {
		return ""
	}
	if strings.has_prefix(info.next, c.base_url) {
		return strings.clone(info.next[len(c.base_url):], allocator)
	}
	return strings.clone(info.next, allocator)
}

@(private)
_header_lookup :: proc(
	headers: map[string]string,
	key: string,
) -> (
	string,
	bool,
) {
	v, ok := headers[strings.to_lower(key, context.temp_allocator)]
	return v, ok
}
