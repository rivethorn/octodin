package octodin

import "core:strings"

// This file covers the search API and the rate-limit / meta endpoints.

// Search_Options carries the shared pagination and sort parameters.
//
// q uses the GitHub search syntax, e.g. "language:odin stars:>100".
// See https://docs.github.com/en/search-github/searching-on-github.
Search_Options :: struct {
	using list: List_Options,
	q:          string,
	sort:       string `json:"sort,omitempty"`,
	order:      string `json:"order,omitempty"`, // "asc" or "desc".
}

_search_path :: proc(
	base: string,
	opts: Search_Options,
	allocator := context.allocator,
) -> string {
	q := query_builder_make(allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts.list, allocator)
	// q is required; add it verbatim (it is already URL-safe when
	// built from terms, see search_terms).
	if opts.q != "" {
		append(&q.params, strings.concatenate({"q=", opts.q}, allocator))
	}
	query_add_string(&q, "sort", opts.sort, allocator)
	query_add_string(&q, "order", opts.order, allocator)
	return with_query(base, &q, allocator)
}

// search_terms joins raw terms with "+" for use as Search_Options.q.
//
// Terms keep their GitHub search syntax verbatim (qualifiers such as
// "language:odin" or "stars:>100"); only URL-structural characters
// (% + & ? # and whitespace) are escaped, and spaces become "+".
search_terms :: proc(
	terms: []string,
	allocator := context.allocator,
) -> string {
	b := strings.builder_make(allocator)
	for t, i in terms {
		if i > 0 {
			strings.write_byte(&b, '+')
		}
		for j := 0; j < len(t); j += 1 {
			switch t[j] {
			case '%':
				strings.write_string(&b, "%25")
			case '+':
				strings.write_string(&b, "%2B")
			case '&':
				strings.write_string(&b, "%26")
			case '?':
				strings.write_string(&b, "%3F")
			case '#':
				strings.write_string(&b, "%23")
			case ' ', '\t':
				strings.write_byte(&b, '+')
			case:
				strings.write_byte(&b, t[j])
			}
		}
	}
	return strings.to_string(b)
}

// search_repositories searches repositories.
search_repositories :: proc(
	c: ^Client,
	opts: Search_Options,
) -> (
	Search_Result(Repository),
	Response,
	Error,
) {
	path := _search_path("/search/repositories", opts, c.allocator)
	defer delete(path)
	return get_into(c, path, Search_Result(Repository))
}

// destroy_search_repositories releases a repository search result.
destroy_search_repositories :: proc(r: ^Search_Result(Repository)) {
	destroy_repositories(r.items)
	r^ = {}
}

// search_issues searches issues and pull requests.
search_issues :: proc(
	c: ^Client,
	opts: Search_Options,
) -> (
	Search_Result(Issue),
	Response,
	Error,
) {
	path := _search_path("/search/issues", opts, c.allocator)
	defer delete(path)
	return get_into(c, path, Search_Result(Issue))
}

// destroy_search_issues releases an issue search result.
destroy_search_issues :: proc(r: ^Search_Result(Issue)) {
	destroy_issues(r.items)
	r^ = {}
}

// search_users searches users.
search_users :: proc(
	c: ^Client,
	opts: Search_Options,
) -> (
	Search_Result(User),
	Response,
	Error,
) {
	path := _search_path("/search/users", opts, c.allocator)
	defer delete(path)
	return get_into(c, path, Search_Result(User))
}

// destroy_search_users releases a user search result.
destroy_search_users :: proc(r: ^Search_Result(User)) {
	destroy_users(r.items)
	r^ = {}
}

// Code_Result is one match of a code search.
Code_Result :: struct {
	name:       string `json:"name"`,
	path:       string `json:"path"`,
	sha:        string `json:"sha"`,
	url:        string `json:"url"`,
	git_url:    string `json:"git_url"`,
	html_url:   string `json:"html_url"`,
	repository: Repository `json:"repository"`,
}

destroy_code_result :: proc(r: ^Code_Result) {
	delete(r.name)
	delete(r.path)
	delete(r.sha)
	delete(r.url)
	delete(r.git_url)
	delete(r.html_url)
	destroy_repository(&r.repository)
	r^ = {}
}

destroy_code_results :: proc(items: []Code_Result) {
	for &r in items {
		destroy_code_result(&r)
	}
	delete(items)
}

// search_code searches code. Requires authentication.
search_code :: proc(
	c: ^Client,
	opts: Search_Options,
) -> (
	Search_Result(Code_Result),
	Response,
	Error,
) {
	path := _search_path("/search/code", opts, c.allocator)
	defer delete(path)
	return get_into(c, path, Search_Result(Code_Result))
}

// destroy_search_code releases a code search result.
destroy_search_code :: proc(r: ^Search_Result(Code_Result)) {
	destroy_code_results(r.items)
	r^ = {}
}

// get_rate_limit reports the caller's quota without consuming quota.
get_rate_limit :: proc(c: ^Client) -> (Rate_Limit_Response, Response, Error) {
	return get_into(c, "/rate_limit", Rate_Limit_Response)
}

// get_meta returns GitHub service IPs and capability flags.
get_meta :: proc(c: ^Client) -> (Meta, Response, Error) {
	return get_into(c, "/meta", Meta)
}

// get_zen returns a random piece of GitHub wisdom.
get_zen :: proc(c: ^Client) -> (string, Response, Error) {
	resp, err := get(c, "/zen")
	if err != nil {
		return "", {}, err
	}
	return strings.clone(string(resp.body), c.allocator), resp, nil
}

// get_octocat returns ASCII Octocat saying `say`.
get_octocat :: proc(
	c: ^Client,
	say: string = "",
) -> (
	string,
	Response,
	Error,
) {
	if say == "" {
		resp, err := get(c, "/octocat")
		if err != nil {
			return "", {}, err
		}
		return strings.clone(string(resp.body), c.allocator), resp, nil
	}
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	query_add_string(&q, "s", say, c.allocator)
	path := with_query("/octocat", &q, c.allocator)
	defer delete(path)
	resp, err := get(c, path)
	if err != nil {
		return "", {}, err
	}
	return strings.clone(string(resp.body), c.allocator), resp, nil
}
