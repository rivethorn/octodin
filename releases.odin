package octodin

import "core:strings"

// This file covers the releases API, including release assets.

// list_releases lists the releases of a repository.
list_releases :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	opts: List_Options = {},
) -> (
	[]Release,
	Response,
	Error,
) {
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts, c.allocator)
	base := _repo_sub(owner, repo, "/releases", c.allocator)
	defer delete(base)
	path := with_query(base, &q, c.allocator)
	defer delete(path)
	return get_into(c, path, []Release)
}

// get_release fetches a release by id.
get_release :: proc(
	c: ^Client,
	owner, repo: string,
	release_id: i64,
) -> (
	Release,
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{"/releases/", _itoa(int(release_id), context.temp_allocator)},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return get_into(c, path, Release)
}

// get_latest_release fetches the latest published release.
get_latest_release :: proc(
	c: ^Client,
	owner, repo: string,
) -> (
	Release,
	Response,
	Error,
) {
	path := _repo_sub(owner, repo, "/releases/latest", c.allocator)
	defer delete(path)
	return get_into(c, path, Release)
}

// get_release_by_tag fetches a release by tag name.
get_release_by_tag :: proc(
	c: ^Client,
	owner, repo, tag: string,
) -> (
	Release,
	Response,
	Error,
) {
	esc := url_escape(tag, c.allocator)
	defer delete(esc)
	suffix := strings.concatenate({"/releases/tags/", esc}, c.allocator)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return get_into(c, path, Release)
}

// Create_Release_Request publishes a release. Only tag_name is required.
Create_Release_Request :: struct {
	tag_name:         string `json:"tag_name"`,
	target_commitish: string `json:"target_commitish,omitempty"`,
	name:             string `json:"name,omitempty"`,
	body:             string `json:"body,omitempty"`,
	draft:            bool `json:"draft,omitempty"`,
	prerelease:       bool `json:"prerelease,omitempty"`,
	make_latest:      Maybe(string) `json:"make_latest,omitempty"`, // "true", "false", "legacy".
}

// create_release publishes a release.
create_release :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	req: Create_Release_Request,
) -> (
	Release,
	Response,
	Error,
) {
	path := _repo_sub(owner, repo, "/releases", c.allocator)
	defer delete(path)
	return send_json(c, .Post, path, req, Release)
}

// Update_Release_Request patches a release. Only set fields are sent.
Update_Release_Request :: struct {
	tag_name:         Maybe(string) `json:"tag_name,omitempty"`,
	target_commitish: Maybe(string) `json:"target_commitish,omitempty"`,
	name:             Maybe(string) `json:"name,omitempty"`,
	body:             Maybe(string) `json:"body,omitempty"`,
	draft:            Maybe(bool) `json:"draft,omitempty"`,
	prerelease:       Maybe(bool) `json:"prerelease,omitempty"`,
	make_latest:      Maybe(string) `json:"make_latest,omitempty"`,
}

// update_release patches a release.
update_release :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	release_id: i64,
	req: Update_Release_Request,
) -> (
	Release,
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{"/releases/", _itoa(int(release_id), context.temp_allocator)},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return send_json(c, .Patch, path, req, Release)
}

// delete_release deletes a release. Tags are kept; delete the tag
// separately via git if needed.
delete_release :: proc(
	c: ^Client,
	owner, repo: string,
	release_id: i64,
) -> (
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{"/releases/", _itoa(int(release_id), context.temp_allocator)},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return del(c, path)
}

// list_release_assets lists the assets of a release.
list_release_assets :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	release_id: i64,
	opts: List_Options = {},
) -> (
	[]Release_Asset,
	Response,
	Error,
) {
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts, c.allocator)
	suffix := strings.concatenate(
		{
			"/releases/",
			_itoa(int(release_id), context.temp_allocator),
			"/assets",
		},
		c.allocator,
	)
	defer delete(suffix)
	base := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(base)
	path := with_query(base, &q, c.allocator)
	defer delete(path)
	return get_into(c, path, []Release_Asset)
}

// get_release_asset fetches a single asset by id.
get_release_asset :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	asset_id: i64,
) -> (
	Release_Asset,
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{"/releases/assets/", _itoa(int(asset_id), context.temp_allocator)},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return get_into(c, path, Release_Asset)
}

// delete_release_asset deletes a release asset.
delete_release_asset :: proc(
	c: ^Client,
	owner, repo: string,
	asset_id: i64,
) -> (
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{"/releases/assets/", _itoa(int(asset_id), context.temp_allocator)},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return del(c, path)
}

// upload_release_asset uploads a file as a release asset.
//
// upload_url is the release's upload_url with its "{?name,label}"
// template intact; name is the file name; content_type is the MIME type
// (e.g. "application/octet-stream"); data is the raw file payload.
upload_release_asset :: proc(
	c: ^Client,
	upload_url: string,
	name: string,
	content_type: string,
	data: []u8,
) -> (
	Release_Asset,
	Response,
	Error,
) {
	template := "{?name,label}"
	url: string
	if idx := strings.index(upload_url, template); idx >= 0 {
		base := upload_url[:idx]
		esc := url_escape(name, context.temp_allocator)
		url = strings.concatenate({base, "?name=", esc}, c.allocator)
	} else {
		esc := url_escape(name, context.temp_allocator)
		url = strings.concatenate({upload_url, "?name=", esc}, c.allocator)
	}
	defer delete(url)
	resp, err := post_raw(c, url, data, content_type)
	if err != nil {
		return {}, {}, err
	}
	asset, derr := decode_body(resp, Release_Asset, c.allocator)
	if derr != nil {
		return {}, resp, derr
	}
	return asset, resp, nil
}
