package github

import "core:mem"
import "core:strings"

// Default values used when the corresponding Config field is left blank.
DEFAULT_BASE_URL :: "https://api.github.com"
DEFAULT_USER_AGENT  :: "OctOdin/0.1.0"
DEFAULT_API_VERSION :: "2022-11-28"

// Config describes how a Client talks to the GitHub API.
Config :: struct {
	// Personal access token (fine-grained or classic), OAuth token, or
	// GitHub App user token. Empty means unauthenticated: public
	// resources only, under the lower unauthenticated rate limit.
	token:       string,
	// API base URL. Defaults to https://api.github.com. Point it at
	// http(s)://HOST/api/v3 for GitHub Enterprise Server.
	base_url:    string,
	user_agent:  string,
	api_version: string,
	// Per-request timeout in seconds. Defaults to 30. Zero or negative
	// values select the default.
	timeout_s:   int,
	// Allocator used for configuration strings, response bodies, and
	// decoded values. Defaults to context.allocator at creation time.
	allocator:   mem.Allocator,
}

// Client is an authenticated handle for the GitHub REST API.
// Create it with client_make and free it with client_destroy.
// A Client is not safe for concurrent use; create one per thread.
Client :: struct {
	token:                    string,
	base_url:                 string,
	user_agent:               string,
	api_version:              string,
	timeout_s:                int,
	allocator:                mem.Allocator,
	_using_default_allocator: bool,
}

// client_make builds a Client from a Config, filling in defaults for
// every blank field. The Client owns clones of the config strings.
client_make :: proc(cfg: Config = {}) -> Client {
	alloc := cfg.allocator
	using_default := false
	if alloc.data == nil && alloc.procedure == nil {
		alloc = context.allocator
		using_default = true
	}

	base := cfg.base_url if cfg.base_url != "" else DEFAULT_BASE_URL
	ua := cfg.user_agent if cfg.user_agent != "" else DEFAULT_USER_AGENT
	ver := cfg.api_version if cfg.api_version != "" else DEFAULT_API_VERSION
	to := cfg.timeout_s if cfg.timeout_s > 0 else 30

	return Client {
		token = strings.clone(cfg.token, alloc),
		base_url = strings.clone(strings.trim_right(base, "/"), alloc),
		user_agent = strings.clone(ua, alloc),
		api_version = strings.clone(ver, alloc),
		timeout_s = to,
		allocator = alloc,
		_using_default_allocator = using_default,
	}
}

// client_destroy releases the strings owned by the Client.
// The Client must not be used afterwards.
client_destroy :: proc(c: ^Client) {
	if c == nil {
		return
	}
	delete(c.token)
	delete(c.base_url)
	delete(c.user_agent)
	delete(c.api_version)
	c^ = {}
}

// client_set_token replaces the token used for authentication.
client_set_token :: proc(c: ^Client, token: string) {
	if c == nil {
		return
	}
	delete(c.token)
	c.token = strings.clone(token, c.allocator)
}

// client_set_base_url replaces the API base URL. Useful for GitHub
// Enterprise Server, e.g. "https://ghe.example.com/api/v3".
client_set_base_url :: proc(c: ^Client, base_url: string) {
	if c == nil {
		return
	}
	delete(c.base_url)
	c.base_url = strings.clone(strings.trim_right(base_url, "/"), c.allocator)
}

// is_authenticated reports whether the Client carries a token.
is_authenticated :: proc(c: ^Client) -> bool {
	return c != nil && len(c.token) > 0
}
