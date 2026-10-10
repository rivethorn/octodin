<div align="center" style="">
    <img src="assets/banner.png" style="height: auto; width: 20vw; object-fit: cover"/>
</div>

An [Odin](https://odin-lang.org) client library for the [GitHub REST API](https://docs.github.com/en/rest),
in the spirit of Octokit. Managed via **[Mimir](https://github.com/rivethorn/mimir)**.

Clone it into your project's `pkgs/` directory and import it by folder name.

## Quick Start

The `example/` directory is a small Mimir project demonstrating the library:

```bash
cd example
mimir run              # Build and run the demo
mimir run -- extended  # Broader tour: issues, search, contents, errors
mimir build            # Compile the demo to bin/
mimir clean            # Clear build files and artifacts
```

The repository root holds the library itself (package `github`, no
`main` package), so it is compiled as a dependency rather than built
directly. `odin build . -build-mode:obj` type-checks it standalone.

The demo talks to public endpoints, so it works with no setup. To
authenticate, either export `GITHUB_TOKEN` or copy `example/.env.example`
to `example/.env` and fill in your token (loaded via
[dotenv-odin](https://github.com/rivethorn/dotenv-odin), never commit it):

```bash
GITHUB_TOKEN=ghp_... mimir run
```

## Usage

The library lives at the repository root (package `github`).
Drop the checkout into your own project's `pkgs/` directory
(e.g. as `pkgs/octodin`) and import it by folder name:

```odin
import github "pkgs:octodin"
```

```odin
client := github.client_make(github.Config{token = "ghp_..."})
defer github.client_destroy(&client)

repo, resp, err := github.get_repo(&client, "odin-lang", "Odin")
if err != nil {
    msg := github.error_message(err)
    defer delete(msg)
    fmt.eprintfln("failed: %s", msg)
    return
}
defer github.response_destroy(&resp)
defer github.destroy_repository(&repo)

fmt.println(repo.full_name, repo.stargazers_count)
fmt.println("rate:", resp.rate.remaining, "/", resp.rate.limit)
```

### Authentication

Pass a token in `github.Config.token`. Fine-grained personal access tokens,
classic tokens, OAuth tokens, and GitHub App user tokens all work — the
library sends them as `Authorization: Bearer <token>`. Omit the token for
public resources (stricter unauthenticated rate limits apply).

For GitHub Enterprise Server, point the client at your instance:

```odin
client := github.client_make(github.Config{
    token    = "...",
    base_url = "https://ghe.example.com/api/v3",
})
```

### Requests

Every endpoint returns `(value, Response, Error)`:

- `Response` carries the HTTP status, headers, body, and parsed
  `X-RateLimit-*` quota. Destroy it with `response_destroy`.
- `Error` is a union of `Transport_Error` (network/TLS failure),
  `Api_Error` (non-2xx status with the API's message), and `Codec_Error`
  (JSON encode/decode failure). Render it with `error_message`, inspect it
  with `is_not_found`, `is_rate_limited`, `is_unauthorized`, and free it
  with `destroy_error`.
- Decoded values are allocated with the client's allocator. Each type has a
  matching destructor (`destroy_repository`, `destroy_issues`, ...).

Endpoints not covered by a typed helper stay reachable through the generic
layer — `do_request`, `get`, `post_raw` / `put_raw` / `patch_raw`, `del`,
`get_into`, `send_json`, and `decode_body`:

```odin
// Typed decode of any endpoint, e.g. a preview API:
resp, err := github.get(&client, "/repos/odin-lang/Odin/traffic/views")
```

### Pagination

List endpoints take option structs embedding `List_Options`:

```odin
issues, resp, err := github.list_repo_issues(
    &client, "odin-lang", "Odin", {per_page = 50, page = 2, state = "open"},
)
```

Follow-up pages come from the `Link` header:

```odin
info := github.page_info(resp)       // next / prev / first / last
next := github.next_page_path(&client, resp)
```

### API coverage

| Area     | Highlights |
| -------- | ---------- |
| Repos    | get, create (user/org), update, delete, branches, commits, contributors, languages, file contents (read/write/delete, base64 helpers) |
| Issues   | list/get/create/update/close/reopen, lock, comments, labels |
| Pulls    | list/get/create/update/close, merge, files, commits, reviews |
| Users    | get user, get/update authenticated user, emails, followers/following |
| Releases | list/get/latest/by-tag/create/update/delete, assets (list/get/delete/upload) |
| Actions  | workflows, runs (list/get/rerun/cancel), jobs |
| Search   | repositories, issues, users, code (`search_terms` builds queries) |
| System   | rate limit, meta, zen, octocat |

### Memory management

The client owns its config strings (`client_destroy`). Each `Response`
owns its body and headers (`response_destroy`). Decoded resources own
their strings, arrays, and maps — free them with the matching `destroy_*`
procedure. If you back the client with an arena or tracking allocator,
you can manage memory your own way instead.

## Requirements

- Odin (a recent `dev-20xx` toolchain) and Mimir
- libcurl (system library on macOS/Linux; used for HTTPS transport)
- Internet access for live API calls

## License

MIT — see [LICENSE](LICENSE). See [GitHub's REST API docs](https://docs.github.com/en/rest) for
endpoint semantics, parameters, and required token scopes.
