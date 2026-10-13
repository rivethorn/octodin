package octodin

import "core:strings"

// This file covers the issues API: issues, comments, and labels.

// _issue_path builds "/repos/{owner}/{repo}/issues[/{number}]".
_issue_path :: proc(
	owner, repo: string,
	number: int = 0,
	allocator := context.allocator,
) -> string {
	base := _repo_sub(owner, repo, "/issues", allocator)
	if number == 0 {
		return base
	}
	defer delete(base)
	return strings.concatenate(
		{base, "/", _itoa(number, context.temp_allocator)},
		allocator,
	)
}

// List_Issues_Options filters issue listings.
List_Issues_Options :: struct {
	using list: List_Options,
	// milestone: number, "none", or "*".
	milestone:  string `json:"milestone,omitempty"`,
	// state: "open", "closed", "all".
	state:      string `json:"state,omitempty"`,
	assignee:   string `json:"assignee,omitempty"`,
	creator:    string `json:"creator,omitempty"`,
	mentioned:  string `json:"mentioned,omitempty"`,
	labels:     string `json:"labels,omitempty"`, // comma-separated.
	sort:       string `json:"sort,omitempty"`, // "created", "updated", "comments".
	direction:  string `json:"direction,omitempty"`,
	since:      string `json:"since,omitempty"`, // RFC 3339.
}

_list_issues_path :: proc(
	base: string,
	opts: List_Issues_Options,
	allocator := context.allocator,
) -> string {
	q := query_builder_make(allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts.list, allocator)
	query_add_string(&q, "milestone", opts.milestone, allocator)
	query_add_string(&q, "state", opts.state, allocator)
	query_add_string(&q, "assignee", opts.assignee, allocator)
	query_add_string(&q, "creator", opts.creator, allocator)
	query_add_string(&q, "mentioned", opts.mentioned, allocator)
	query_add_string(&q, "labels", opts.labels, allocator)
	query_add_string(&q, "sort", opts.sort, allocator)
	query_add_string(&q, "direction", opts.direction, allocator)
	query_add_string(&q, "since", opts.since, allocator)
	return with_query(base, &q, allocator)
}

// list_repo_issues lists issues of a repository.
list_repo_issues :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	opts: List_Issues_Options = {},
) -> (
	[]Issue,
	Response,
	Error,
) {
	base := _issue_path(owner, repo, 0, c.allocator)
	defer delete(base)
	path := _list_issues_path(base, opts, c.allocator)
	defer delete(path)
	return get_into(c, path, []Issue)
}

// list_own_issues lists issues assigned to the authenticated user across
// owned, assigned, mentioned, and subscribed scopes.
list_own_issues :: proc(
	c: ^Client,
	opts: List_Issues_Options = {},
	filter: string = "",
) -> (
	[]Issue,
	Response,
	Error,
) {
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts.list, c.allocator)
	query_add_string(&q, "filter", filter, c.allocator)
	query_add_string(&q, "state", opts.state, c.allocator)
	query_add_string(&q, "labels", opts.labels, c.allocator)
	query_add_string(&q, "sort", opts.sort, c.allocator)
	query_add_string(&q, "direction", opts.direction, c.allocator)
	query_add_string(&q, "since", opts.since, c.allocator)
	path := with_query("/issues", &q, c.allocator)
	defer delete(path)
	return get_into(c, path, []Issue)
}

// get_issue fetches a single issue by number.
get_issue :: proc(
	c: ^Client,
	owner, repo: string,
	number: int,
) -> (
	Issue,
	Response,
	Error,
) {
	path := _issue_path(owner, repo, number, c.allocator)
	defer delete(path)
	return get_into(c, path, Issue)
}

// Create_Issue_Request opens a new issue. Only title is required.
Create_Issue_Request :: struct {
	title:     string `json:"title"`,
	body:      string `json:"body,omitempty"`,
	milestone: Maybe(int) `json:"milestone,omitempty"`,
	labels:    []string `json:"labels,omitempty"`,
	assignees: []string `json:"assignees,omitempty"`,
}

// create_issue opens a new issue.
create_issue :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	req: Create_Issue_Request,
) -> (
	Issue,
	Response,
	Error,
) {
	path := _issue_path(owner, repo, 0, c.allocator)
	defer delete(path)
	return send_json(c, .Post, path, req, Issue)
}

// Update_Issue_Request patches an issue. Only set fields are sent.
Update_Issue_Request :: struct {
	title:        Maybe(string) `json:"title,omitempty"`,
	body:         Maybe(string) `json:"body,omitempty"`,
	state:        Maybe(string) `json:"state,omitempty"`, // "open", "closed".
	state_reason: Maybe(string) `json:"state_reason,omitempty"`, // "completed", "not_planned", "reopened".
	milestone:    Maybe(int) `json:"milestone,omitempty"`,
	labels:       []string `json:"labels,omitempty"`,
	assignees:    []string `json:"assignees,omitempty"`,
}

// update_issue patches an issue.
update_issue :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	req: Update_Issue_Request,
) -> (
	Issue,
	Response,
	Error,
) {
	path := _issue_path(owner, repo, number, c.allocator)
	defer delete(path)
	return send_json(c, .Patch, path, req, Issue)
}

// close_issue closes an issue with an optional reason.
close_issue :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	reason: string = "",
) -> (
	Issue,
	Response,
	Error,
) {
	req := Update_Issue_Request {
		state = "closed",
	}
	if reason != "" {
		req.state_reason = reason
	}
	return update_issue(c, owner, repo, number, req)
}

// reopen_issue reopens an issue.
reopen_issue :: proc(
	c: ^Client,
	owner, repo: string,
	number: int,
) -> (
	Issue,
	Response,
	Error,
) {
	return update_issue(
		c,
		owner,
		repo,
		number,
		Update_Issue_Request{state = "open", state_reason = "reopened"},
	)
}

// lock_issue locks an issue, optionally with a reason
// ("off-topic", "too heated", "resolved", "spam").
lock_issue :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	reason: string = "",
) -> (
	Response,
	Error,
) {
	Lock_Request :: struct {
		lock_reason: string `json:"lock_reason,omitempty"`,
	}
	suffix := strings.concatenate(
		{"/issues/", _itoa(number, context.temp_allocator), "/lock"},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return send_json_noresponse(
		c,
		.Put,
		path,
		Lock_Request{lock_reason = reason},
	)
}

// unlock_issue unlocks an issue.
unlock_issue :: proc(
	c: ^Client,
	owner, repo: string,
	number: int,
) -> (
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{"/issues/", _itoa(number, context.temp_allocator), "/lock"},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return del(c, path)
}

// list_issue_comments lists comments on an issue.
list_issue_comments :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	opts: List_Options = {},
) -> (
	[]Comment,
	Response,
	Error,
) {
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts, c.allocator)
	suffix := strings.concatenate(
		{"/issues/", _itoa(number, context.temp_allocator), "/comments"},
		c.allocator,
	)
	defer delete(suffix)
	base := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(base)
	path := with_query(base, &q, c.allocator)
	defer delete(path)
	return get_into(c, path, []Comment)
}

// get_comment fetches a single issue comment by id.
get_comment :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	comment_id: i64,
) -> (
	Comment,
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{"/issues/comments/", _itoa(int(comment_id), context.temp_allocator)},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return get_into(c, path, Comment)
}

// create_comment posts a comment on an issue.
create_comment :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	body: string,
) -> (
	Comment,
	Response,
	Error,
) {
	Comment_Request :: struct {
		body: string `json:"body"`,
	}
	suffix := strings.concatenate(
		{"/issues/", _itoa(number, context.temp_allocator), "/comments"},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return send_json(c, .Post, path, Comment_Request{body = body}, Comment)
}

// update_comment edits an issue comment.
update_comment :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	comment_id: i64,
	body: string,
) -> (
	Comment,
	Response,
	Error,
) {
	Comment_Request :: struct {
		body: string `json:"body"`,
	}
	suffix := strings.concatenate(
		{"/issues/comments/", _itoa(int(comment_id), context.temp_allocator)},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return send_json(c, .Patch, path, Comment_Request{body = body}, Comment)
}

// delete_comment deletes an issue comment.
delete_comment :: proc(
	c: ^Client,
	owner, repo: string,
	comment_id: i64,
) -> (
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{"/issues/comments/", _itoa(int(comment_id), context.temp_allocator)},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return del(c, path)
}

// list_issue_labels lists the labels on an issue.
list_issue_labels :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
) -> (
	[]Label,
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{"/issues/", _itoa(number, context.temp_allocator), "/labels"},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return get_into(c, path, []Label)
}

// replace_issue_labels replaces all labels on an issue.
replace_issue_labels :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	labels: []string,
) -> (
	[]Label,
	Response,
	Error,
) {
	Labels_Request :: struct {
		labels: []string `json:"labels"`,
	}
	suffix := strings.concatenate(
		{"/issues/", _itoa(number, context.temp_allocator), "/labels"},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return send_json(c, .Put, path, Labels_Request{labels = labels}, []Label)
}

// add_issue_labels adds labels to an issue.
add_issue_labels :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	labels: []string,
) -> (
	[]Label,
	Response,
	Error,
) {
	Labels_Request :: struct {
		labels: []string `json:"labels"`,
	}
	suffix := strings.concatenate(
		{"/issues/", _itoa(number, context.temp_allocator), "/labels"},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return send_json(c, .Post, path, Labels_Request{labels = labels}, []Label)
}

// remove_issue_label removes one label from an issue.
remove_issue_label :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	number: int,
	label: string,
) -> (
	Response,
	Error,
) {
	esc := url_escape(label, c.allocator)
	defer delete(esc)
	mid := strings.concatenate(
		{"/issues/", _itoa(number, context.temp_allocator), "/labels/", esc},
		c.allocator,
	)
	defer delete(mid)
	path := _repo_sub(owner, repo, mid, c.allocator)
	defer delete(path)
	return del(c, path)
}

// list_repo_labels lists all labels of a repository.
list_repo_labels :: proc(
	c: ^Client,
	owner, repo: string,
) -> (
	[]Label,
	Response,
	Error,
) {
	path := _repo_sub(owner, repo, "/labels", c.allocator)
	defer delete(path)
	return get_into(c, path, []Label)
}
