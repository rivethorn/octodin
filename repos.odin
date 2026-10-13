package octodin

import "core:encoding/base64"
import "core:strings"

// This file covers the repositories API: repository CRUD, branches,
// commits, contents (files), contributors, and languages.

// _repo_path builds "/repos/{owner}/{repo}". The caller owns the result.
_repo_path :: proc(
	owner, repo: string,
	allocator := context.allocator,
) -> string {
	return strings.concatenate({"/repos/", owner, "/", repo}, allocator)
}

// _repo_sub builds "/repos/{owner}/{repo}{suffix}" in one allocation.
// The caller owns the result.
_repo_sub :: proc(
	owner, repo, suffix: string,
	allocator := context.allocator,
) -> string {
	return strings.concatenate(
		{"/repos/", owner, "/", repo, suffix},
		allocator,
	)
}

// get_repo fetches a single repository.
get_repo :: proc(
	c: ^Client,
	owner, repo: string,
) -> (
	Repository,
	Response,
	Error,
) {
	path := _repo_path(owner, repo, c.allocator)
	defer delete(path)
	return get_into(c, path, Repository)
}

// delete_repo deletes a repository. Requires the "delete_repo" scope.
delete_repo :: proc(c: ^Client, owner, repo: string) -> (Response, Error) {
	path := _repo_path(owner, repo, c.allocator)
	defer delete(path)
	return del(c, path)
}

// Create_Repo_Request describes a new repository. Only name is required.
Create_Repo_Request :: struct {
	name:                   string `json:"name"`,
	description:            string `json:"description,omitempty"`,
	homepage:               string `json:"homepage,omitempty"`,
	private:                bool `json:"private"`,
	has_issues:             Maybe(bool) `json:"has_issues,omitempty"`,
	has_projects:           Maybe(bool) `json:"has_projects,omitempty"`,
	has_wiki:               Maybe(bool) `json:"has_wiki,omitempty"`,
	has_downloads:          Maybe(bool) `json:"has_downloads,omitempty"`,
	is_template:            bool `json:"is_template,omitempty"`,
	auto_init:              bool `json:"auto_init,omitempty"`,
	gitignore_template:     string `json:"gitignore_template,omitempty"`,
	license_template:       string `json:"license_template,omitempty"`,
	default_branch:         string `json:"default_branch,omitempty"`,
	allow_squash_merge:     Maybe(bool) `json:"allow_squash_merge,omitempty"`,
	allow_merge_commit:     Maybe(bool) `json:"allow_merge_commit,omitempty"`,
	allow_rebase_merge:     Maybe(bool) `json:"allow_rebase_merge,omitempty"`,
	delete_branch_on_merge: Maybe(
		bool,
	) `json:"delete_branch_on_merge,omitempty"`,
}

// create_user_repo creates a repository for the authenticated user.
create_user_repo :: proc(
	c: ^Client,
	req: Create_Repo_Request,
) -> (
	Repository,
	Response,
	Error,
) {
	return send_json(c, .Post, "/user/repos", req, Repository)
}

// create_org_repo creates a repository in an organization.
create_org_repo :: proc(
	c: ^Client,
	org: string,
	req: Create_Repo_Request,
) -> (
	Repository,
	Response,
	Error,
) {
	path := strings.concatenate({"/orgs/", org, "/repos"}, c.allocator)
	defer delete(path)
	return send_json(c, .Post, path, req, Repository)
}

// Update_Repo_Request patches repository settings. Only set fields are sent.
Update_Repo_Request :: struct {
	name:                   Maybe(string) `json:"name,omitempty"`,
	description:            Maybe(string) `json:"description,omitempty"`,
	homepage:               Maybe(string) `json:"homepage,omitempty"`,
	private:                Maybe(bool) `json:"private,omitempty"`,
	has_issues:             Maybe(bool) `json:"has_issues,omitempty"`,
	has_projects:           Maybe(bool) `json:"has_projects,omitempty"`,
	has_wiki:               Maybe(bool) `json:"has_wiki,omitempty"`,
	default_branch:         Maybe(string) `json:"default_branch,omitempty"`,
	archived:               Maybe(bool) `json:"archived,omitempty"`,
	allow_squash_merge:     Maybe(bool) `json:"allow_squash_merge,omitempty"`,
	allow_merge_commit:     Maybe(bool) `json:"allow_merge_commit,omitempty"`,
	allow_rebase_merge:     Maybe(bool) `json:"allow_rebase_merge,omitempty"`,
	delete_branch_on_merge: Maybe(
		bool,
	) `json:"delete_branch_on_merge,omitempty"`,
}

// update_repo patches repository settings.
update_repo :: proc(
	c: ^Client,
	owner, repo: string,
	req: Update_Repo_Request,
) -> (
	Repository,
	Response,
	Error,
) {
	path := _repo_path(owner, repo, c.allocator)
	defer delete(path)
	return send_json(c, .Patch, path, req, Repository)
}

// List_Repos_Options filters repository listings.
List_Repos_Options :: struct {
	using list: List_Options,
	// type: "all", "owner", "public", "private", "member".
	type:       string `json:"type,omitempty"`,
	sort:       string `json:"sort,omitempty"`, // "created", "updated", "pushed", "full_name".
	direction:  string `json:"direction,omitempty"`, // "asc", "desc".
}

_list_repos_path :: proc(
	base: string,
	opts: List_Repos_Options,
	allocator := context.allocator,
) -> string {
	q := query_builder_make(allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts.list, allocator)
	query_add_string(&q, "type", opts.type, allocator)
	query_add_string(&q, "sort", opts.sort, allocator)
	query_add_string(&q, "direction", opts.direction, allocator)
	return with_query(base, &q, allocator)
}

// list_user_repos lists public repositories of a user.
list_user_repos :: proc(
	c: ^Client,
	user: string,
	opts: List_Repos_Options = {},
) -> (
	[]Repository,
	Response,
	Error,
) {
	base := strings.concatenate({"/users/", user, "/repos"}, c.allocator)
	defer delete(base)
	path := _list_repos_path(base, opts, c.allocator)
	defer delete(path)
	return get_into(c, path, []Repository)
}

// list_own_repos lists repositories of the authenticated user.
list_own_repos :: proc(
	c: ^Client,
	opts: List_Repos_Options = {},
) -> (
	[]Repository,
	Response,
	Error,
) {
	path := _list_repos_path("/user/repos", opts, c.allocator)
	defer delete(path)
	return get_into(c, path, []Repository)
}

// list_org_repos lists repositories of an organization.
list_org_repos :: proc(
	c: ^Client,
	org: string,
	opts: List_Repos_Options = {},
) -> (
	[]Repository,
	Response,
	Error,
) {
	base := strings.concatenate({"/orgs/", org, "/repos"}, c.allocator)
	defer delete(base)
	path := _list_repos_path(base, opts, c.allocator)
	defer delete(path)
	return get_into(c, path, []Repository)
}

// list_branches lists the branches of a repository.
list_branches :: proc(
	c: ^Client,
	owner, repo: string,
	opts: List_Options = {},
) -> (
	[]Branch,
	Response,
	Error,
) {
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts, c.allocator)
	base := _repo_sub(owner, repo, "/branches", c.allocator)
	defer delete(base)
	path := with_query(base, &q, c.allocator)
	defer delete(path)
	return get_into(c, path, []Branch)
}

// get_branch fetches a single branch.
get_branch :: proc(
	c: ^Client,
	owner, repo, branch: string,
) -> (
	Branch,
	Response,
	Error,
) {
	esc := url_escape(branch, c.allocator)
	defer delete(esc)
	suffix := strings.concatenate({"/branches/", esc}, c.allocator)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return get_into(c, path, Branch)
}

// List_Commits_Options filters commit listings.
List_Commits_Options :: struct {
	using list: List_Options,
	sha:        string `json:"sha,omitempty"`,
	path:       string `json:"path,omitempty"`,
	author:     string `json:"author,omitempty"`,
	since:      string `json:"since,omitempty"`, // RFC 3339.
	until:      string `json:"until,omitempty"`, // RFC 3339.
}

// list_commits lists commits of a repository.
list_commits :: proc(
	c: ^Client,
	owner, repo: string,
	opts: List_Commits_Options = {},
) -> (
	[]Commit,
	Response,
	Error,
) {
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts.list, c.allocator)
	query_add_string(&q, "sha", opts.sha, c.allocator)
	query_add_string(&q, "path", opts.path, c.allocator)
	query_add_string(&q, "author", opts.author, c.allocator)
	query_add_string(&q, "since", opts.since, c.allocator)
	query_add_string(&q, "until", opts.until, c.allocator)
	base := _repo_sub(owner, repo, "/commits", c.allocator)
	defer delete(base)
	path := with_query(base, &q, c.allocator)
	defer delete(path)
	return get_into(c, path, []Commit)
}

// get_commit fetches a single commit by SHA.
get_commit :: proc(
	c: ^Client,
	owner, repo, sha: string,
) -> (
	Commit,
	Response,
	Error,
) {
	suffix := strings.concatenate({"/commits/", sha}, c.allocator)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return get_into(c, path, Commit)
}

// list_contributors lists contributors, ordered by commits (desc).
list_contributors :: proc(
	c: ^Client,
	owner, repo: string,
	opts: List_Options = {},
	anon: bool = false,
) -> (
	[]Contributor,
	Response,
	Error,
) {
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts, c.allocator)
	if anon {
		query_add_string(&q, "anon", "1", c.allocator)
	}
	base := _repo_sub(owner, repo, "/contributors", c.allocator)
	defer delete(base)
	path := with_query(base, &q, c.allocator)
	defer delete(path)
	return get_into(c, path, []Contributor)
}

// list_languages returns byte counts per language.
list_languages :: proc(
	c: ^Client,
	owner, repo: string,
) -> (
	map[string]int,
	Response,
	Error,
) {
	path := _repo_sub(owner, repo, "/languages", c.allocator)
	defer delete(path)
	return get_into(c, path, map[string]int)
}

// _content_path builds "/repos/{owner}/{repo}/contents/{path}[?ref=]".
_content_path :: proc(
	owner, repo, path, ref: string,
	allocator := context.allocator,
) -> string {
	// Each path segment is escaped individually so slashes survive.
	escaped := _escape_content_path(path, allocator)
	defer delete(escaped)
	base := strings.concatenate(
		{"/repos/", owner, "/", repo, "/contents/", escaped},
		allocator,
	)
	if ref == "" {
		return base
	}
	defer delete(base)
	q := query_builder_make(allocator)
	defer query_builder_destroy(&q)
	query_add_string(&q, "ref", ref, allocator)
	return with_query(base, &q, allocator)
}

@(private)
_escape_content_path :: proc(
	path: string,
	allocator := context.allocator,
) -> string {
	b := strings.builder_make(allocator)
	for seg, i in strings.split(path, "/", context.temp_allocator) {
		if i > 0 {
			strings.write_byte(&b, '/')
		}
		strings.write_string(&b, url_escape(seg, context.temp_allocator))
	}
	return strings.to_string(b)
}

// get_content_file fetches a single file's metadata and content.
get_content_file :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	path: string,
	ref: string = "",
) -> (
	Content_Entry,
	Response,
	Error,
) {
	p := _content_path(owner, repo, path, ref, c.allocator)
	defer delete(p)
	return get_into(c, p, Content_Entry)
}

// list_content_dir lists a directory. Use path "" for the repository root.
list_content_dir :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	path: string,
	ref: string = "",
) -> (
	[]Content_Entry,
	Response,
	Error,
) {
	p := _content_path(owner, repo, path, ref, c.allocator)
	defer delete(p)
	return get_into(c, p, []Content_Entry)
}

// encode_file_content base64-encodes raw file bytes for the contents API.
encode_file_content :: proc(
	raw: []u8,
	allocator := context.allocator,
) -> string {
	encoded, _ := base64.encode(raw, allocator = allocator)
	return encoded
}

// decode_file_content decodes a Content_Entry payload. Only "base64" is
// supported; other encodings return an error.
decode_file_content :: proc(
	e: Content_Entry,
	allocator := context.allocator,
) -> (
	[]u8,
	Error,
) {
	if e.encoding != "" && e.encoding != "base64" {
		return nil, Codec_Error {
			message = strings.concatenate(
				{"github: unsupported content encoding: ", e.encoding},
				allocator,
			),
		}
	}
	clean := _strip_whitespace(e.content, context.temp_allocator)
	decoded, derr := base64.decode(string(clean), allocator = allocator)
	if derr != nil {
		return nil, Codec_Error {
			message = strings.clone(
				"github: invalid base64 file content",
				allocator,
			),
		}
	}
	return decoded, nil
}

// Write_File_Request creates or updates a file. sha is required for
// updates (pass the blob sha being replaced) and must be empty on create.
Write_File_Request :: struct {
	message:   string `json:"message"`,
	content:   string `json:"content"`,
	sha:       string `json:"sha,omitempty"`,
	branch:    string `json:"branch,omitempty"`,
	committer: Maybe(Git_User) `json:"committer,omitempty"`,
	author:    Maybe(Git_User) `json:"author,omitempty"`,
}

// File_Write_Response answers a create/update/delete of a file.
File_Write_Response :: struct {
	content: Content_Entry `json:"content"`,
	commit:  Commit `json:"commit"`,
}

destroy_file_write_response :: proc(r: ^File_Write_Response) {
	destroy_content_entry(&r.content)
	destroy_commit(&r.commit)
	r^ = {}
}

// create_or_update_file creates or updates a file. content must already be
// base64-encoded (see encode_file_content).
create_or_update_file :: proc(
	c: ^Client,
	owner, repo, path: string,
	req: Write_File_Request,
) -> (
	File_Write_Response,
	Response,
	Error,
) {
	p := _content_path(owner, repo, path, "", c.allocator)
	defer delete(p)
	return send_json(c, .Put, p, req, File_Write_Response)
}

// delete_file deletes a file. sha is the blob being deleted.
delete_file :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	path: string,
	message: string,
	sha: string,
	branch: string = "",
) -> (
	File_Write_Response,
	Response,
	Error,
) {
	Delete_File_Request :: struct {
		message: string `json:"message"`,
		sha:     string `json:"sha"`,
		branch:  string `json:"branch,omitempty"`,
	}
	p := _content_path(owner, repo, path, "", c.allocator)
	defer delete(p)
	return send_json(
		c,
		.Delete,
		p,
		Delete_File_Request{message = message, sha = sha, branch = branch},
		File_Write_Response,
	)
}

@(private)
_strip_whitespace :: proc(
	s: string,
	allocator := context.allocator,
) -> string {
	b := strings.builder_make(allocator)
	for i := 0; i < len(s); i += 1 {
		if s[i] != '\n' && s[i] != '\r' && s[i] != ' ' && s[i] != '\t' {
			strings.write_byte(&b, s[i])
		}
	}
	return strings.to_string(b)
}
