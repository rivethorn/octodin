package main

import "core:fmt"
import "core:os"

import dotenv "pkgs:dotenv"
import github "../.."

// Demonstrates the github library against public endpoints.
//
// The token is read from the environment, or from an `example/.env` file
// (see `.env.example`). The demo works without one, under the lower
// unauthenticated rate limit.
//
// Usage:
//	mimir run              # repository overview
//	mimir run -- extended   # broader tour: issues, search, contents, errors
main :: proc() {
	// Missing file is fine: real environment variables still apply.
	_, _ = dotenv.load()

	if len(os.args) > 1 && os.args[1] == "extended" {
		run_extended()
		return
	}

	token := os.get_env("GITHUB_TOKEN", context.temp_allocator)

	client := github.client_make(github.Config{token = token})
	defer github.client_destroy(&client)

	if github.is_authenticated(&client) {
		fmt.println("Authenticated: yes")
	} else {
		fmt.println("Authenticated: no (public data only, lower rate limit)")
	}

	repo, repo_resp, repo_err := github.get_repo(&client, "odin-lang", "Odin")
	if repo_err != nil {
		msg := github.error_message(repo_err)
		fmt.eprintfln("get_repo failed: %s", msg)
		delete(msg)
		github.destroy_error(&repo_err)
		os.exit(1)
	}
	defer github.response_destroy(&repo_resp)
	defer github.destroy_repository(&repo)

	fmt.printf("Repository:  %s\n", repo.full_name)
	fmt.printf("Description: %s\n", repo.description)
	fmt.printf(
		"Stars:       %d   Forks: %d   Open issues: %d\n",
		repo.stargazers_count,
		repo.forks_count,
		repo.open_issues_count,
	)
	fmt.printf(
		"Language:    %s   Default branch: %s\n",
		repo.language,
		repo.default_branch,
	)
	fmt.printf(
		"Rate limit:  %d/%d remaining\n",
		repo_resp.rate.remaining,
		repo_resp.rate.limit,
	)

	release, rel_resp, rel_err := github.get_latest_release(
		&client,
		"odin-lang",
		"Odin",
	)
	if rel_err != nil {
		if !github.is_not_found(rel_err) {
			msg := github.error_message(rel_err)
			fmt.eprintfln("get_latest_release failed: %s", msg)
			delete(msg)
		}
		github.destroy_error(&rel_err)
	} else {
		defer github.response_destroy(&rel_resp)
		defer github.destroy_release(&release)
		fmt.printf("Latest:      %s (%s)\n", release.tag_name, release.name)
	}

	contribs, c_resp, c_err := github.list_contributors(
		&client,
		"odin-lang",
		"Odin",
		{per_page = 5},
	)
	if c_err != nil {
		msg := github.error_message(c_err)
		fmt.eprintfln("list_contributors failed: %s", msg)
		delete(msg)
		github.destroy_error(&c_err)
		os.exit(1)
	}
	defer github.response_destroy(&c_resp)
	defer github.destroy_contributors(contribs)

	fmt.println("Top contributors:")
	for c in contribs {
		fmt.printf("  %-24s %d commits\n", c.login, c.contributions)
	}

	info := github.page_info(c_resp)
	if info.has_next {
		fmt.println("(more pages available via the Link header)")
	}
}

// run_extended exercises more of the library: users, issues, search,
// contents, rate limits, and error handling.
run_extended :: proc() {
	token := os.get_env("GITHUB_TOKEN", context.temp_allocator)

	client := github.client_make(github.Config{token = token})
	defer github.client_destroy(&client)

	check :: proc(ok: bool, what: string) {
		if !ok {
			fmt.eprintfln("FAILED: %s", what)
			os.exit(1)
		}
		fmt.printf("ok: %s\n", what)
	}

	// Users.
	user, user_resp, user_err := github.get_user(&client, "gingerBill")
	check(user_err == nil, "get_user")
	fmt.printf(
		"  %s (%s), followers: %d\n",
		user.login,
		user.name,
		user.followers,
	)
	github.response_destroy(&user_resp)
	github.destroy_user(&user)

	// Issues.
	issues, issues_resp, issues_err := github.list_repo_issues(
		&client,
		"odin-lang",
		"Odin",
		{per_page = 3},
	)
	check(issues_err == nil, "list_repo_issues")
	for i in issues {
		fmt.printf("  #%d %s [%s]\n", i.number, i.title, i.state)
	}
	github.response_destroy(&issues_resp)
	github.destroy_issues(issues)

	// Pulls.
	pulls, pulls_resp, pulls_err := github.list_pulls(
		&client,
		"odin-lang",
		"Odin",
		{per_page = 2},
	)
	check(pulls_err == nil, "list_pulls")
	for p in pulls {
		fmt.printf("  PR #%d %s\n", p.number, p.title)
	}
	github.response_destroy(&pulls_resp)
	github.destroy_pull_requests(pulls)

	// Search.
	query := github.search_terms(
		{"language:odin", "stars:>100"},
		context.temp_allocator,
	)
	results, search_resp, search_err := github.search_repositories(
		&client,
		{q = query, per_page = 3},
	)
	check(search_err == nil, "search_repositories")
	fmt.printf("  total: %d\n", results.total_count)
	for r in results.items {
		fmt.printf("  %s (%d stars)\n", r.full_name, r.stargazers_count)
	}
	github.response_destroy(&search_resp)
	github.destroy_search_repositories(&results)

	// Contents + base64 round trip.
	entry, content_resp, content_err := github.get_content_file(
		&client,
		"odin-lang",
		"Odin",
		"README.md",
	)
	check(content_err == nil, "get_content_file")
	raw, raw_err := github.decode_file_content(entry, context.temp_allocator)
	check(raw_err == nil, "decode_file_content")
	fmt.printf(
		"  README.md: %d bytes on disk, encoding=%s\n",
		len(raw),
		entry.encoding,
	)
	github.response_destroy(&content_resp)
	github.destroy_content_entry(&entry)

	// Rate limit + meta + zen.
	limits, limits_resp, limits_err := github.get_rate_limit(&client)
	check(limits_err == nil, "get_rate_limit")
	fmt.printf(
		"  core: %d/%d remaining\n",
		limits.resources["core"].remaining,
		limits.resources["core"].limit,
	)
	github.response_destroy(&limits_resp)
	github.destroy_rate_limit_response(&limits)

	zen, zen_resp, zen_err := github.get_zen(&client)
	check(zen_err == nil, "get_zen")
	fmt.printf("  zen: %s\n", zen)
	delete(zen)
	github.response_destroy(&zen_resp)

	// Error handling: a missing repo must surface a 404 Api_Error.
	_, nf_resp, nf_err := github.get_repo(
		&client,
		"odin-lang",
		"this-repo-does-not-exist-xyz",
	)
	check(nf_err != nil && github.is_not_found(nf_err), "404 handling")
	msg := github.error_message(nf_err)
	fmt.printf("  message: %s\n", msg)
	delete(msg)
	github.destroy_error(&nf_err)
	github.response_destroy(&nf_resp)

	fmt.println("All extended checks passed.")
}
