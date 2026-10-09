package github

import "core:strings"

// This file covers the users API.

// get_user fetches a user by username.
get_user :: proc(c: ^Client, username: string) -> (User, Response, Error) {
	path := strings.concatenate({"/users/", username}, c.allocator)
	defer delete(path)
	return get_into(c, path, User)
}

// get_authenticated_user fetches the user the token belongs to.
// Requires authentication.
get_authenticated_user :: proc(c: ^Client) -> (User, Response, Error) {
	return get_into(c, "/user", User)
}

// Update_User_Request patches the authenticated user's profile.
// Only set fields are sent.
Update_User_Request :: struct {
	name:             Maybe(string) `json:"name,omitempty"`,
	email:            Maybe(string) `json:"email,omitempty"`,
	blog:             Maybe(string) `json:"blog,omitempty"`,
	twitter_username: Maybe(string) `json:"twitter_username,omitempty"`,
	company:          Maybe(string) `json:"company,omitempty"`,
	location:         Maybe(string) `json:"location,omitempty"`,
	hireable:         Maybe(bool) `json:"hireable,omitempty"`,
	bio:              Maybe(string) `json:"bio,omitempty"`,
}

// update_authenticated_user patches the authenticated user's profile.
update_authenticated_user :: proc(
	c: ^Client,
	req: Update_User_Request,
) -> (
	User,
	Response,
	Error,
) {
	return send_json(c, .Patch, "/user", req, User)
}

// list_user_emails lists the authenticated user's email addresses.
// Requires the "user:email" scope.
list_user_emails :: proc(c: ^Client) -> ([]Email_Address, Response, Error) {
	return get_into(c, "/user/emails", []Email_Address)
}

// list_followers lists a user's followers.
list_followers :: proc(
	c: ^Client,
	username: string,
	opts: List_Options = {},
) -> (
	[]User,
	Response,
	Error,
) {
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts, c.allocator)
	base := strings.concatenate(
		{"/users/", username, "/followers"},
		c.allocator,
	)
	defer delete(base)
	path := with_query(base, &q, c.allocator)
	defer delete(path)
	return get_into(c, path, []User)
}

// list_following lists the users a user follows.
list_following :: proc(
	c: ^Client,
	username: string,
	opts: List_Options = {},
) -> (
	[]User,
	Response,
	Error,
) {
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts, c.allocator)
	base := strings.concatenate(
		{"/users/", username, "/following"},
		c.allocator,
	)
	defer delete(base)
	path := with_query(base, &q, c.allocator)
	defer delete(path)
	return get_into(c, path, []User)
}
