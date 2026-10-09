// Package github is a client library for the GitHub REST API (api.github.com).
//
// It follows the spirit of Octokit and similar toolkits: a small,
// resource-oriented surface over a shared, authenticated HTTP client.
//
// Quick start:
//
//	client := github.client_make(github.Config{token = os.get_env("GITHUB_TOKEN")})
//	defer github.client_destroy(&client)
//
//	repo, resp, err := github.get_repo(&client, "odin-lang", "Odin")
//	if err != nil {
//		fmt.println(github.error_message(err))
//		return
//	}
//	defer github.response_destroy(&resp)
//	defer github.destroy(repo)
//	fmt.println(repo.full_name, repo.stargazers_count)
//
// Design notes:
//
// - The client owns its configuration strings. Free it with client_destroy.
// - Every request returns a Response that owns its body and headers.
//   Free it with response_destroy when you are done.
// - Decoded values returned by the typed helpers are allocated with the
//   client's allocator. Free them with the matching destroy procedure
//   (e.g. destroy_repo, destroy_repos) or delete/free them directly if
//   you know their layout.
// - Timestamps are kept as RFC 3339 strings, exactly as the API returns
//   them, so callers can decide how (and whether) to parse them.
// - Endpoints that are not covered by a typed helper remain reachable
//   through the generic do_request / get_into / request_json procedures.
//
// Authentication uses a fine-grained personal access token, a classic
// token, or a GitHub App user token, passed as Config.token. Requests
// without a token work for public resources, subject to the stricter
// unauthenticated rate limits.
package github
