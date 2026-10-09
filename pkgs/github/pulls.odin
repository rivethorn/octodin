package github

import "core:strings"

// This file covers the pull-requests API.

// List_Pulls_Options filters pull-request listings.
List_Pulls_Options :: struct {
	using list: List_Options,
	// state: "open", "closed", "all".
	state:      string `json:"state,omitempty"`,
	head:       string `json:"head,omitempty"`,
	base:       string `json:"base,omitempty"`,
	sort:       string `json:"sort,omitempty"`, // "created", "updated", "popularity", "long-running".
	direction:  string `json:"direction,omitempty"`,
}

// list_pulls lists pull requests of a repository.
list_pulls :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	opts: List_Pulls_Options = {},
) -> (
	[]Pull_Request,
	Response,
	Error,
) {
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts.list, c.allocator)
	query_add_string(&q, "state", opts.state, c.allocator)
	query_add_string(&q, "head", opts.head, c.allocator)
	query_add_string(&q, "base", opts.base, c.allocator)
	query_add_string(&q, "sort", opts.sort, c.allocator)
	query_add_string(&q, "direction", opts.direction, c.allocator)
	base := _repo_sub(owner, repo, "/pulls", c.allocator)
	defer delete(base)
	path := with_query(base, &q, c.allocator)
	defer delete(path)
	return get_into(c, path, []Pull_Request)
}

// get_pull fetches a single pull request by number.
get_pull :: proc(
	c: ^Client,
	owner, repo: string,
	number: int,
) -> (
	Pull_Request,
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{"/pulls/", _itoa(number, context.temp_allocator)},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return get_into(c, path, Pull_Request)
}

// Create_Pull_Request opens a new pull request.
Create_Pull_Request :: struct {
	title:                 string `json:"title"`,
	head:                  string `json:"head"`,
	base:                  string `json:"base"`,
	body:                  string `json:"body,omitempty"`,
	draft:                 bool `json:"draft,omitempty"`,
	maintainer_can_modify: Maybe(
		bool,
	) `json:"maintainer_can_modify,omitempty"`,
}

// create_pull opens a new pull request.
create_pull :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	req: Create_Pull_Request,
) -> (
	Pull_Request,
	Response,
	Error,
) {
	path := _repo_sub(owner, repo, "/pulls", c.allocator)
	defer delete(path)
	return send_json(c, .Post, path, req, Pull_Request)
}

// Update_Pull_Request patches a pull request. Only set fields are sent.
Update_Pull_Request :: struct {
	title:                 Maybe(string) `json:"title,omitempty"`,
	body:                  Maybe(string) `json:"body,omitempty"`,
	state:                 Maybe(string) `json:"state,omitempty"`, // "open", "closed".
	base:                  Maybe(string) `json:"base,omitempty"`,
	maintainer_can_modify: Maybe(
		bool,
	) `json:"maintainer_can_modify,omitempty"`,
}

// update_pull patches a pull request.
update_pull :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	req: Update_Pull_Request,
) -> (
	Pull_Request,
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{"/pulls/", _itoa(number, context.temp_allocator)},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return send_json(c, .Patch, path, req, Pull_Request)
}

// close_pull closes a pull request without merging.
close_pull :: proc(
	c: ^Client,
	owner, repo: string,
	number: int,
) -> (
	Pull_Request,
	Response,
	Error,
) {
	return update_pull(
		c,
		owner,
		repo,
		number,
		Update_Pull_Request{state = "closed"},
	)
}

// Merge_Request merges a pull request.
Merge_Request :: struct {
	commit_title:   string `json:"commit_title,omitempty"`,
	commit_message: string `json:"commit_message,omitempty"`,
	// merge_method: "merge", "squash", "rebase".
	merge_method:   string `json:"merge_method,omitempty"`,
	sha:            string `json:"sha,omitempty"`,
}

// Merge_Result answers a merge.
Merge_Result :: struct {
	sha:     string `json:"sha"`,
	merged:  bool `json:"merged"`,
	message: string `json:"message"`,
}

destroy_merge_result :: proc(r: ^Merge_Result) {
	delete(r.sha)
	delete(r.message)
	r^ = {}
}

// merge_pull merges a pull request.
merge_pull :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	req: Merge_Request = {},
) -> (
	Merge_Result,
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{"/pulls/", _itoa(number, context.temp_allocator), "/merge"},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return send_json(c, .Put, path, req, Merge_Result)
}

// list_pull_files lists the changed files of a pull request.
list_pull_files :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	opts: List_Options = {},
) -> (
	[]Pull_Request_File,
	Response,
	Error,
) {
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts, c.allocator)
	suffix := strings.concatenate(
		{"/pulls/", _itoa(number, context.temp_allocator), "/files"},
		c.allocator,
	)
	defer delete(suffix)
	base := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(base)
	path := with_query(base, &q, c.allocator)
	defer delete(path)
	return get_into(c, path, []Pull_Request_File)
}

// list_pull_commits lists the commits of a pull request.
list_pull_commits :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	opts: List_Options = {},
) -> (
	[]Commit,
	Response,
	Error,
) {
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts, c.allocator)
	suffix := strings.concatenate(
		{"/pulls/", _itoa(number, context.temp_allocator), "/commits"},
		c.allocator,
	)
	defer delete(suffix)
	base := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(base)
	path := with_query(base, &q, c.allocator)
	defer delete(path)
	return get_into(c, path, []Commit)
}

// list_reviews lists the reviews of a pull request.
list_reviews :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	opts: List_Options = {},
) -> (
	[]Review,
	Response,
	Error,
) {
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts, c.allocator)
	suffix := strings.concatenate(
		{"/pulls/", _itoa(number, context.temp_allocator), "/reviews"},
		c.allocator,
	)
	defer delete(suffix)
	base := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(base)
	path := with_query(base, &q, c.allocator)
	defer delete(path)
	return get_into(c, path, []Review)
}

// get_review fetches a single review by id.
get_review :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	review_id: i64,
) -> (
	Review,
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{
			"/pulls/",
			_itoa(number, context.temp_allocator),
			"/reviews/",
			_itoa(int(review_id), context.temp_allocator),
		},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return get_into(c, path, Review)
}

// Create_Review_Request submits a review.
// event: "APPROVE", "REQUEST_CHANGES", "COMMENT".
Create_Review_Request :: struct {
	commit_id: string `json:"commit_id,omitempty"`,
	body:      string `json:"body,omitempty"`,
	event:     string `json:"event,omitempty"`,
}

// create_review submits a review on a pull request.
create_review :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	req: Create_Review_Request,
) -> (
	Review,
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{"/pulls/", _itoa(number, context.temp_allocator), "/reviews"},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return send_json(c, .Post, path, req, Review)
}

// delete_pending_review deletes a pending review.
delete_pending_review :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	review_id: i64,
) -> (
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{
			"/pulls/",
			_itoa(number, context.temp_allocator),
			"/reviews/",
			_itoa(int(review_id), context.temp_allocator),
		},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return del(c, path)
}
