package github

// This file defines the resource types returned by the GitHub REST API.
//
// Conventions:
//
// - Field names and JSON tags mirror the API exactly.
// - Timestamps are RFC 3339 strings, exactly as returned.
// - A JSON null decodes to the zero value ("", 0, false, empty).
//   Presence checks: milestone.number == 0 means "no milestone",
//   issue.pull_request.url != "" means "is a pull request".
// - Every type has a destroy_<name> procedure (and destroy_<name>s for
//   slices) that releases heap memory. Values decoded by this library
//   are allocated with the client's allocator; callers using an arena
//   or tracking allocator may manage memory their own way instead.

// Rate_Limit carries the quota headers attached to every API response.
Rate_Limit :: struct {
	limit:         int,
	remaining:     int,
	reset:         int, // Unix epoch seconds at which the window resets.
	used:          int,
	retry_after_s: int, // Present on secondary rate-limit responses.
}

// Rate_Limit_Resource is one quota bucket of the /rate_limit endpoint.
Rate_Limit_Resource :: struct {
	limit:     int `json:"limit"`,
	remaining: int `json:"remaining"`,
	reset:     int `json:"reset"`,
	used:      int `json:"used"`,
	resource:  string `json:"resource"`,
}

// Rate_Limit_Response is the body of GET /rate_limit.
Rate_Limit_Response :: struct {
	resources: map[string]Rate_Limit_Resource `json:"resources"`,
	rate:      Rate_Limit_Resource `json:"rate"`,
}

destroy_rate_limit_response :: proc(r: ^Rate_Limit_Response) {
	for k, v in r.resources {
		delete(k)
		delete(v.resource)
	}
	delete(r.resources)
	delete(r.rate.resource)
	r^ = {}
}

// User is a GitHub user or organization account.
User :: struct {
	login:               string `json:"login"`,
	id:                  i64 `json:"id"`,
	node_id:             string `json:"node_id"`,
	avatar_url:          string `json:"avatar_url"`,
	gravatar_id:         string `json:"gravatar_id"`,
	url:                 string `json:"url"`,
	html_url:            string `json:"html_url"`,
	followers_url:       string `json:"followers_url"`,
	following_url:       string `json:"following_url"`,
	gists_url:           string `json:"gists_url"`,
	starred_url:         string `json:"starred_url"`,
	subscriptions_url:   string `json:"subscriptions_url"`,
	organizations_url:   string `json:"organizations_url"`,
	repos_url:           string `json:"repos_url"`,
	events_url:          string `json:"events_url"`,
	received_events_url: string `json:"received_events_url"`,
	type:                string `json:"type"`,
	site_admin:          bool `json:"site_admin"`,
	name:                string `json:"name"`,
	company:             string `json:"company"`,
	blog:                string `json:"blog"`,
	location:            string `json:"location"`,
	email:               string `json:"email"`,
	hireable:            bool `json:"hireable"`,
	bio:                 string `json:"bio"`,
	twitter_username:    string `json:"twitter_username"`,
	public_repos:        int `json:"public_repos"`,
	public_gists:        int `json:"public_gists"`,
	followers:           int `json:"followers"`,
	following:           int `json:"following"`,
	created_at:          string `json:"created_at"`,
	updated_at:          string `json:"updated_at"`,
}

destroy_user :: proc(u: ^User) {
	delete(u.login)
	delete(u.node_id)
	delete(u.avatar_url)
	delete(u.gravatar_id)
	delete(u.url)
	delete(u.html_url)
	delete(u.followers_url)
	delete(u.following_url)
	delete(u.gists_url)
	delete(u.starred_url)
	delete(u.subscriptions_url)
	delete(u.organizations_url)
	delete(u.repos_url)
	delete(u.events_url)
	delete(u.received_events_url)
	delete(u.type)
	delete(u.name)
	delete(u.company)
	delete(u.blog)
	delete(u.location)
	delete(u.email)
	delete(u.bio)
	delete(u.twitter_username)
	delete(u.created_at)
	delete(u.updated_at)
	u^ = {}
}

destroy_users :: proc(users: []User) {
	for &u in users {
		destroy_user(&u)
	}
	delete(users)
}

// Email_Address is one entry of GET /user/emails.
Email_Address :: struct {
	email:      string `json:"email"`,
	primary:    bool `json:"primary"`,
	verified:   bool `json:"verified"`,
	visibility: string `json:"visibility"`,
}

destroy_email_address :: proc(e: ^Email_Address) {
	delete(e.email)
	delete(e.visibility)
	e^ = {}
}

destroy_email_addresses :: proc(emails: []Email_Address) {
	for &e in emails {
		destroy_email_address(&e)
	}
	delete(emails)
}

// License is an SPDX license record attached to a repository.
License :: struct {
	key:     string `json:"key"`,
	name:    string `json:"name"`,
	spdx_id: string `json:"spdx_id"`,
	url:     string `json:"url"`,
	node_id: string `json:"node_id"`,
}

destroy_license :: proc(l: ^License) {
	delete(l.key)
	delete(l.name)
	delete(l.spdx_id)
	delete(l.url)
	delete(l.node_id)
	l^ = {}
}

// Repository is a GitHub repository.
Repository :: struct {
	id:                i64 `json:"id"`,
	node_id:           string `json:"node_id"`,
	name:              string `json:"name"`,
	full_name:         string `json:"full_name"`,
	owner:             User `json:"owner"`,
	private:           bool `json:"private"`,
	html_url:          string `json:"html_url"`,
	description:       string `json:"description"`,
	fork:              bool `json:"fork"`,
	url:               string `json:"url"`,
	archive_url:       string `json:"archive_url"`,
	assignees_url:     string `json:"assignees_url"`,
	blobs_url:         string `json:"blobs_url"`,
	branches_url:      string `json:"branches_url"`,
	collaborators_url: string `json:"collaborators_url"`,
	commits_url:       string `json:"commits_url"`,
	compare_url:       string `json:"compare_url"`,
	contents_url:      string `json:"contents_url"`,
	contributors_url:  string `json:"contributors_url"`,
	deployments_url:   string `json:"deployments_url"`,
	downloads_url:     string `json:"downloads_url"`,
	events_url:        string `json:"events_url"`,
	forks_url:         string `json:"forks_url"`,
	git_commits_url:   string `json:"git_commits_url"`,
	git_refs_url:      string `json:"git_refs_url"`,
	git_tags_url:      string `json:"git_tags_url"`,
	hooks_url:         string `json:"hooks_url"`,
	issue_comment_url: string `json:"issue_comment_url"`,
	issue_events_url:  string `json:"issue_events_url"`,
	issues_url:        string `json:"issues_url"`,
	keys_url:          string `json:"keys_url"`,
	labels_url:        string `json:"labels_url"`,
	languages_url:     string `json:"languages_url"`,
	merges_url:        string `json:"merges_url"`,
	milestones_url:    string `json:"milestones_url"`,
	notifications_url: string `json:"notifications_url"`,
	pulls_url:         string `json:"pulls_url"`,
	releases_url:      string `json:"releases_url"`,
	stargazers_url:    string `json:"stargazers_url"`,
	statuses_url:      string `json:"statuses_url"`,
	subscribers_url:   string `json:"subscribers_url"`,
	subscription_url:  string `json:"subscription_url"`,
	tags_url:          string `json:"tags_url"`,
	teams_url:         string `json:"teams_url"`,
	trees_url:         string `json:"trees_url"`,
	clone_url:         string `json:"clone_url"`,
	mirror_url:        string `json:"mirror_url"`,
	ssh_url:           string `json:"ssh_url"`,
	svn_url:           string `json:"svn_url"`,
	homepage:          string `json:"homepage"`,
	language:          string `json:"language"`,
	forks_count:       int `json:"forks_count"`,
	stargazers_count:  int `json:"stargazers_count"`,
	watchers_count:    int `json:"watchers_count"`,
	size:              int `json:"size"`,
	default_branch:    string `json:"default_branch"`,
	open_issues_count: int `json:"open_issues_count"`,
	is_template:       bool `json:"is_template"`,
	topics:            []string `json:"topics"`,
	has_issues:        bool `json:"has_issues"`,
	has_projects:      bool `json:"has_projects"`,
	has_wiki:          bool `json:"has_wiki"`,
	has_pages:         bool `json:"has_pages"`,
	has_downloads:     bool `json:"has_downloads"`,
	has_discussions:   bool `json:"has_discussions"`,
	archived:          bool `json:"archived"`,
	disabled:          bool `json:"disabled"`,
	visibility:        string `json:"visibility"`,
	pushed_at:         string `json:"pushed_at"`,
	created_at:        string `json:"created_at"`,
	updated_at:        string `json:"updated_at"`,
	license:           License `json:"license"`,
	forks:             int `json:"forks"`,
	open_issues:       int `json:"open_issues"`,
	watchers:          int `json:"watchers"`,
}

destroy_repository :: proc(r: ^Repository) {
	destroy_user(&r.owner)
	delete(r.node_id)
	delete(r.name)
	delete(r.full_name)
	delete(r.html_url)
	delete(r.description)
	delete(r.url)
	delete(r.archive_url)
	delete(r.assignees_url)
	delete(r.blobs_url)
	delete(r.branches_url)
	delete(r.collaborators_url)
	delete(r.commits_url)
	delete(r.compare_url)
	delete(r.contents_url)
	delete(r.contributors_url)
	delete(r.deployments_url)
	delete(r.downloads_url)
	delete(r.events_url)
	delete(r.forks_url)
	delete(r.git_commits_url)
	delete(r.git_refs_url)
	delete(r.git_tags_url)
	delete(r.hooks_url)
	delete(r.issue_comment_url)
	delete(r.issue_events_url)
	delete(r.issues_url)
	delete(r.keys_url)
	delete(r.labels_url)
	delete(r.languages_url)
	delete(r.merges_url)
	delete(r.milestones_url)
	delete(r.notifications_url)
	delete(r.pulls_url)
	delete(r.releases_url)
	delete(r.stargazers_url)
	delete(r.statuses_url)
	delete(r.subscribers_url)
	delete(r.subscription_url)
	delete(r.tags_url)
	delete(r.teams_url)
	delete(r.trees_url)
	delete(r.clone_url)
	delete(r.mirror_url)
	delete(r.ssh_url)
	delete(r.svn_url)
	delete(r.homepage)
	delete(r.language)
	delete(r.default_branch)
	for t in r.topics {
		delete(t)
	}
	delete(r.topics)
	delete(r.visibility)
	delete(r.pushed_at)
	delete(r.created_at)
	delete(r.updated_at)
	destroy_license(&r.license)
	r^ = {}
}

destroy_repositories :: proc(repos: []Repository) {
	for &r in repos {
		destroy_repository(&r)
	}
	delete(repos)
}

// Contributor pairs a User with a commit count (contributors endpoints).
Contributor :: struct {
	login:         string `json:"login"`,
	id:            i64 `json:"id"`,
	avatar_url:    string `json:"avatar_url"`,
	html_url:      string `json:"html_url"`,
	type:          string `json:"type"`,
	contributions: int `json:"contributions"`,
}

destroy_contributor :: proc(c: ^Contributor) {
	delete(c.login)
	delete(c.avatar_url)
	delete(c.html_url)
	delete(c.type)
	c^ = {}
}

destroy_contributors :: proc(items: []Contributor) {
	for &c in items {
		destroy_contributor(&c)
	}
	delete(items)
}

// Label is an issue / pull-request label.
Label :: struct {
	id:          i64 `json:"id"`,
	node_id:     string `json:"node_id"`,
	url:         string `json:"url"`,
	name:        string `json:"name"`,
	description: string `json:"description"`,
	color:       string `json:"color"`,
	default:     bool `json:"default"`,
}

destroy_label :: proc(l: ^Label) {
	delete(l.node_id)
	delete(l.url)
	delete(l.name)
	delete(l.description)
	delete(l.color)
	l^ = {}
}

destroy_labels :: proc(labels: []Label) {
	for &l in labels {
		destroy_label(&l)
	}
	delete(labels)
}

// Milestone is an issue milestone. number == 0 means "none".
Milestone :: struct {
	id:            i64 `json:"id"`,
	number:        int `json:"number"`,
	title:         string `json:"title"`,
	description:   string `json:"description"`,
	state:         string `json:"state"`,
	open_issues:   int `json:"open_issues"`,
	closed_issues: int `json:"closed_issues"`,
	created_at:    string `json:"created_at"`,
	updated_at:    string `json:"updated_at"`,
	closed_at:     string `json:"closed_at"`,
	due_on:        string `json:"due_on"`,
	creator:       User `json:"creator"`,
}

destroy_milestone :: proc(m: ^Milestone) {
	delete(m.title)
	delete(m.description)
	delete(m.state)
	delete(m.created_at)
	delete(m.updated_at)
	delete(m.closed_at)
	delete(m.due_on)
	destroy_user(&m.creator)
	m^ = {}
}

// Pull_Request_Ref is the "pull_request" links object embedded in issues
// that are pull requests. url == "" means "plain issue".
Pull_Request_Ref :: struct {
	url:       string `json:"url"`,
	html_url:  string `json:"html_url"`,
	diff_url:  string `json:"diff_url"`,
	patch_url: string `json:"patch_url"`,
	merged_at: string `json:"merged_at"`,
}

destroy_pull_request_ref :: proc(r: ^Pull_Request_Ref) {
	delete(r.url)
	delete(r.html_url)
	delete(r.diff_url)
	delete(r.patch_url)
	delete(r.merged_at)
	r^ = {}
}

// Issue is a GitHub issue (or a pull request when pull_request.url != "").
Issue :: struct {
	id:                 i64 `json:"id"`,
	node_id:            string `json:"node_id"`,
	url:                string `json:"url"`,
	html_url:           string `json:"html_url"`,
	number:             int `json:"number"`,
	state:              string `json:"state"`,
	state_reason:       string `json:"state_reason"`,
	title:              string `json:"title"`,
	body:               string `json:"body"`,
	user:               User `json:"user"`,
	labels:             []Label `json:"labels"`,
	assignees:          []User `json:"assignees"`,
	milestone:          Milestone `json:"milestone"`,
	locked:             bool `json:"locked"`,
	comments:           int `json:"comments"`,
	created_at:         string `json:"created_at"`,
	updated_at:         string `json:"updated_at"`,
	closed_at:          string `json:"closed_at"`,
	author_association: string `json:"author_association"`,
	pull_request:       Pull_Request_Ref `json:"pull_request"`,
}

destroy_issue :: proc(i: ^Issue) {
	delete(i.node_id)
	delete(i.url)
	delete(i.html_url)
	delete(i.state)
	delete(i.state_reason)
	delete(i.title)
	delete(i.body)
	destroy_user(&i.user)
	destroy_labels(i.labels)
	for &a in i.assignees {
		destroy_user(&a)
	}
	delete(i.assignees)
	destroy_milestone(&i.milestone)
	delete(i.created_at)
	delete(i.updated_at)
	delete(i.closed_at)
	delete(i.author_association)
	destroy_pull_request_ref(&i.pull_request)
	i^ = {}
}

destroy_issues :: proc(issues: []Issue) {
	for &i in issues {
		destroy_issue(&i)
	}
	delete(issues)
}

// Comment is an issue or pull-request comment.
Comment :: struct {
	id:         i64 `json:"id"`,
	node_id:    string `json:"node_id"`,
	url:        string `json:"url"`,
	html_url:   string `json:"html_url"`,
	body:       string `json:"body"`,
	user:       User `json:"user"`,
	created_at: string `json:"created_at"`,
	updated_at: string `json:"updated_at"`,
}

destroy_comment :: proc(c: ^Comment) {
	delete(c.node_id)
	delete(c.url)
	delete(c.html_url)
	delete(c.body)
	destroy_user(&c.user)
	delete(c.created_at)
	delete(c.updated_at)
	c^ = {}
}

destroy_comments :: proc(comments: []Comment) {
	for &c in comments {
		destroy_comment(&c)
	}
	delete(comments)
}

// Git_User is the git identity embedded in commits and tags.
Git_User :: struct {
	name:  string `json:"name"`,
	email: string `json:"email"`,
	date:  string `json:"date"`,
}

destroy_git_user :: proc(u: ^Git_User) {
	delete(u.name)
	delete(u.email)
	delete(u.date)
	u^ = {}
}

// Commit_Ref is a {sha, url, html_url} triple pointing at a commit.
Commit_Ref :: struct {
	sha:      string `json:"sha"`,
	url:      string `json:"url"`,
	html_url: string `json:"html_url"`,
}

destroy_commit_ref :: proc(r: ^Commit_Ref) {
	delete(r.sha)
	delete(r.url)
	delete(r.html_url)
	r^ = {}
}

// Commit_Detail is the inner "commit" object of a commit resource.
Commit_Detail :: struct {
	message:       string `json:"message"`,
	author:        Git_User `json:"author"`,
	committer:     Git_User `json:"committer"`,
	comment_count: int `json:"comment_count"`,
}

destroy_commit_detail :: proc(d: ^Commit_Detail) {
	delete(d.message)
	destroy_git_user(&d.author)
	destroy_git_user(&d.committer)
	d^ = {}
}

// Commit_Stats holds addition/deletion totals.
Commit_Stats :: struct {
	additions: int `json:"additions"`,
	deletions: int `json:"deletions"`,
	total:     int `json:"total"`,
}

// Commit is a repository commit.
Commit :: struct {
	sha:       string `json:"sha"`,
	node_id:   string `json:"node_id"`,
	url:       string `json:"url"`,
	html_url:  string `json:"html_url"`,
	commit:    Commit_Detail `json:"commit"`,
	author:    User `json:"author"`,
	committer: User `json:"committer"`,
	parents:   []Commit_Ref `json:"parents"`,
	stats:     Commit_Stats `json:"stats"`,
}

destroy_commit :: proc(c: ^Commit) {
	delete(c.sha)
	delete(c.node_id)
	delete(c.url)
	delete(c.html_url)
	destroy_commit_detail(&c.commit)
	destroy_user(&c.author)
	destroy_user(&c.committer)
	for &p in c.parents {
		destroy_commit_ref(&p)
	}
	delete(c.parents)
	c^ = {}
}

destroy_commits :: proc(commits: []Commit) {
	for &c in commits {
		destroy_commit(&c)
	}
	delete(commits)
}

// Branch is a repository branch.
Branch :: struct {
	name:      string `json:"name"`,
	commit:    Commit_Ref `json:"commit"`,
	protected: bool `json:"protected"`,
}

destroy_branch :: proc(b: ^Branch) {
	delete(b.name)
	destroy_commit_ref(&b.commit)
	b^ = {}
}

destroy_branches :: proc(branches: []Branch) {
	for &b in branches {
		destroy_branch(&b)
	}
	delete(branches)
}

// Content_Entry is a file or directory entry from the contents API.
// For files, content holds the (base64) payload when requested.
Content_Entry :: struct {
	name:         string `json:"name"`,
	path:         string `json:"path"`,
	sha:          string `json:"sha"`,
	size:         int `json:"size"`,
	url:          string `json:"url"`,
	html_url:     string `json:"html_url"`,
	git_url:      string `json:"git_url"`,
	download_url: string `json:"download_url"`,
	type:         string `json:"type"`,
	content:      string `json:"content"`,
	encoding:     string `json:"encoding"`,
}

destroy_content_entry :: proc(e: ^Content_Entry) {
	delete(e.name)
	delete(e.path)
	delete(e.sha)
	delete(e.url)
	delete(e.html_url)
	delete(e.git_url)
	delete(e.download_url)
	delete(e.type)
	delete(e.content)
	delete(e.encoding)
	e^ = {}
}

destroy_content_entries :: proc(entries: []Content_Entry) {
	for &e in entries {
		destroy_content_entry(&e)
	}
	delete(entries)
}

// Pull_Ref is one side (head/base) of a pull request.
Pull_Ref :: struct {
	label: string `json:"label"`,
	ref:   string `json:"ref"`,
	sha:   string `json:"sha"`,
	user:  User `json:"user"`,
	repo:  Repository `json:"repo"`,
}

destroy_pull_ref :: proc(r: ^Pull_Ref) {
	delete(r.label)
	delete(r.ref)
	delete(r.sha)
	destroy_user(&r.user)
	destroy_repository(&r.repo)
	r^ = {}
}

// Pull_Request is a GitHub pull request.
Pull_Request :: struct {
	id:                 i64 `json:"id"`,
	node_id:            string `json:"node_id"`,
	url:                string `json:"url"`,
	html_url:           string `json:"html_url"`,
	number:             int `json:"number"`,
	state:              string `json:"state"`,
	locked:             bool `json:"locked"`,
	title:              string `json:"title"`,
	body:               string `json:"body"`,
	user:               User `json:"user"`,
	labels:             []Label `json:"labels"`,
	milestone:          Milestone `json:"milestone"`,
	created_at:         string `json:"created_at"`,
	updated_at:         string `json:"updated_at"`,
	closed_at:          string `json:"closed_at"`,
	merged_at:          string `json:"merged_at"`,
	merge_commit_sha:   string `json:"merge_commit_sha"`,
	merged:             bool `json:"merged"`,
	mergeable:          bool `json:"mergeable"`,
	mergeable_state:    string `json:"mergeable_state"`,
	merged_by:          User `json:"merged_by"`,
	comments:           int `json:"comments"`,
	review_comments:    int `json:"review_comments"`,
	commits:            int `json:"commits"`,
	additions:          int `json:"additions"`,
	deletions:          int `json:"deletions"`,
	changed_files:      int `json:"changed_files"`,
	head:               Pull_Ref `json:"head"`,
	base:               Pull_Ref `json:"base"`,
	author_association: string `json:"author_association"`,
	draft:              bool `json:"draft"`,
}

destroy_pull_request :: proc(p: ^Pull_Request) {
	delete(p.node_id)
	delete(p.url)
	delete(p.html_url)
	delete(p.state)
	delete(p.title)
	delete(p.body)
	destroy_user(&p.user)
	destroy_labels(p.labels)
	destroy_milestone(&p.milestone)
	delete(p.created_at)
	delete(p.updated_at)
	delete(p.closed_at)
	delete(p.merged_at)
	delete(p.merge_commit_sha)
	delete(p.mergeable_state)
	destroy_user(&p.merged_by)
	destroy_pull_ref(&p.head)
	destroy_pull_ref(&p.base)
	delete(p.author_association)
	p^ = {}
}

destroy_pull_requests :: proc(pulls: []Pull_Request) {
	for &p in pulls {
		destroy_pull_request(&p)
	}
	delete(pulls)
}

// Pull_Request_File is one changed file of a pull request.
Pull_Request_File :: struct {
	sha:          string `json:"sha"`,
	filename:     string `json:"filename"`,
	status:       string `json:"status"`,
	additions:    int `json:"additions"`,
	deletions:    int `json:"deletions"`,
	changes:      int `json:"changes"`,
	blob_url:     string `json:"blob_url"`,
	raw_url:      string `json:"raw_url"`,
	contents_url: string `json:"contents_url"`,
	patch:        string `json:"patch"`,
}

destroy_pull_request_file :: proc(f: ^Pull_Request_File) {
	delete(f.sha)
	delete(f.filename)
	delete(f.status)
	delete(f.blob_url)
	delete(f.raw_url)
	delete(f.contents_url)
	delete(f.patch)
	f^ = {}
}

destroy_pull_request_files :: proc(files: []Pull_Request_File) {
	for &f in files {
		destroy_pull_request_file(&f)
	}
	delete(files)
}

// Review is a pull-request review.
Review :: struct {
	id:           i64 `json:"id"`,
	node_id:      string `json:"node_id"`,
	user:         User `json:"user"`,
	body:         string `json:"body"`,
	state:        string `json:"state"`,
	commit_id:    string `json:"commit_id"`,
	submitted_at: string `json:"submitted_at"`,
	html_url:     string `json:"html_url"`,
}

destroy_review :: proc(r: ^Review) {
	delete(r.node_id)
	destroy_user(&r.user)
	delete(r.body)
	delete(r.state)
	delete(r.commit_id)
	delete(r.submitted_at)
	delete(r.html_url)
	r^ = {}
}

destroy_reviews :: proc(reviews: []Review) {
	for &r in reviews {
		destroy_review(&r)
	}
	delete(reviews)
}

// Release_Asset is a downloadable release artifact.
Release_Asset :: struct {
	id:                   i64 `json:"id"`,
	url:                  string `json:"url"`,
	browser_download_url: string `json:"browser_download_url"`,
	name:                 string `json:"name"`,
	label:                string `json:"label"`,
	state:                string `json:"state"`,
	content_type:         string `json:"content_type"`,
	size:                 int `json:"size"`,
	download_count:       int `json:"download_count"`,
	created_at:           string `json:"created_at"`,
	updated_at:           string `json:"updated_at"`,
}

destroy_release_asset :: proc(a: ^Release_Asset) {
	delete(a.url)
	delete(a.browser_download_url)
	delete(a.name)
	delete(a.label)
	delete(a.state)
	delete(a.content_type)
	delete(a.created_at)
	delete(a.updated_at)
	a^ = {}
}

// Release is a published (or drafted) release.
Release :: struct {
	id:               i64 `json:"id"`,
	node_id:          string `json:"node_id"`,
	url:              string `json:"url"`,
	html_url:         string `json:"html_url"`,
	tag_name:         string `json:"tag_name"`,
	target_commitish: string `json:"target_commitish"`,
	name:             string `json:"name"`,
	body:             string `json:"body"`,
	draft:            bool `json:"draft"`,
	prerelease:       bool `json:"prerelease"`,
	created_at:       string `json:"created_at"`,
	published_at:     string `json:"published_at"`,
	author:           User `json:"author"`,
	assets:           []Release_Asset `json:"assets"`,
}

destroy_release :: proc(r: ^Release) {
	delete(r.node_id)
	delete(r.url)
	delete(r.html_url)
	delete(r.tag_name)
	delete(r.target_commitish)
	delete(r.name)
	delete(r.body)
	delete(r.created_at)
	delete(r.published_at)
	destroy_user(&r.author)
	for &a in r.assets {
		destroy_release_asset(&a)
	}
	delete(r.assets)
	r^ = {}
}

destroy_releases :: proc(releases: []Release) {
	for &r in releases {
		destroy_release(&r)
	}
	delete(releases)
}

// Workflow is an Actions workflow definition.
Workflow :: struct {
	id:         i64 `json:"id"`,
	node_id:    string `json:"node_id"`,
	name:       string `json:"name"`,
	path:       string `json:"path"`,
	state:      string `json:"state"`,
	created_at: string `json:"created_at"`,
	updated_at: string `json:"updated_at"`,
	url:        string `json:"url"`,
	html_url:   string `json:"html_url"`,
	badge_url:  string `json:"badge_url"`,
}

destroy_workflow :: proc(w: ^Workflow) {
	delete(w.node_id)
	delete(w.name)
	delete(w.path)
	delete(w.state)
	delete(w.created_at)
	delete(w.updated_at)
	delete(w.url)
	delete(w.html_url)
	delete(w.badge_url)
	w^ = {}
}

destroy_workflows :: proc(workflows: []Workflow) {
	for &w in workflows {
		destroy_workflow(&w)
	}
	delete(workflows)
}

// Workflow_Run is a single execution of a workflow.
Workflow_Run :: struct {
	id:          i64 `json:"id"`,
	name:        string `json:"name"`,
	head_branch: string `json:"head_branch"`,
	head_sha:    string `json:"head_sha"`,
	run_number:  int `json:"run_number"`,
	event:       string `json:"event"`,
	status:      string `json:"status"`,
	conclusion:  string `json:"conclusion"`,
	workflow_id: i64 `json:"workflow_id"`,
	created_at:  string `json:"created_at"`,
	updated_at:  string `json:"updated_at"`,
	html_url:    string `json:"html_url"`,
	actor:       User `json:"actor"`,
}

destroy_workflow_run :: proc(r: ^Workflow_Run) {
	delete(r.name)
	delete(r.head_branch)
	delete(r.head_sha)
	delete(r.event)
	delete(r.status)
	delete(r.conclusion)
	delete(r.created_at)
	delete(r.updated_at)
	delete(r.html_url)
	destroy_user(&r.actor)
	r^ = {}
}

destroy_workflow_runs :: proc(runs: []Workflow_Run) {
	for &r in runs {
		destroy_workflow_run(&r)
	}
	delete(runs)
}

// Job_Step is a single step of an Actions job.
Job_Step :: struct {
	name:         string `json:"name"`,
	status:       string `json:"status"`,
	conclusion:   string `json:"conclusion"`,
	number:       int `json:"number"`,
	started_at:   string `json:"started_at"`,
	completed_at: string `json:"completed_at"`,
}

destroy_job_step :: proc(s: ^Job_Step) {
	delete(s.name)
	delete(s.status)
	delete(s.conclusion)
	delete(s.started_at)
	delete(s.completed_at)
	s^ = {}
}

// Job is a workflow run's job.
Job :: struct {
	id:           i64 `json:"id"`,
	run_id:       i64 `json:"run_id"`,
	name:         string `json:"name"`,
	status:       string `json:"status"`,
	conclusion:   string `json:"conclusion"`,
	started_at:   string `json:"started_at"`,
	completed_at: string `json:"completed_at"`,
	html_url:     string `json:"html_url"`,
	steps:        []Job_Step `json:"steps"`,
}

destroy_job :: proc(j: ^Job) {
	delete(j.name)
	delete(j.status)
	delete(j.conclusion)
	delete(j.started_at)
	delete(j.completed_at)
	delete(j.html_url)
	for &s in j.steps {
		destroy_job_step(&s)
	}
	delete(j.steps)
	j^ = {}
}

destroy_jobs :: proc(jobs: []Job) {
	for &j in jobs {
		destroy_job(&j)
	}
	delete(jobs)
}

// Search_Result is the envelope of every /search/* endpoint.
Search_Result :: struct($T: typeid) {
	total_count:        int `json:"total_count"`,
	incomplete_results: bool `json:"incomplete_results"`,
	items:              []T `json:"items"`,
}

// Meta is the body of GET /meta: service IPs and capabilities.
Meta :: struct {
	verifiable_password_authentication: bool `json:"verifiable_password_authentication"`,
	ssh_key_fingerprints:               map[string]string `json:"ssh_key_fingerprints"`,
	hooks:                              []string `json:"hooks"`,
	web:                                []string `json:"web"`,
	api:                                []string `json:"api"`,
	git:                                []string `json:"git"`,
	packages:                           []string `json:"packages"`,
	pages:                              []string `json:"pages"`,
	importer:                           []string `json:"importer"`,
	actions:                            []string `json:"actions"`,
}

destroy_meta :: proc(m: ^Meta) {
	for k, v in m.ssh_key_fingerprints {
		delete(k)
		delete(v)
	}
	delete(m.ssh_key_fingerprints)
	_destroy_strings(m.hooks)
	_destroy_strings(m.web)
	_destroy_strings(m.api)
	_destroy_strings(m.git)
	_destroy_strings(m.packages)
	_destroy_strings(m.pages)
	_destroy_strings(m.importer)
	_destroy_strings(m.actions)
	m^ = {}
}

@(private)
_destroy_strings :: proc(s: []string) {
	for x in s {
		delete(x)
	}
	delete(s)
}
