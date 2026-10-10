# dotenv

An [Odin](https://odin-lang.org) library managed via **Mimir** for reading
`.env` files. Call one function at startup and every variable becomes
available through the usual `os.get_env`.

## Quick Start

Clone it into your project's `pkgs/` directory and import it by folder name.

```odin
package main

import "core:fmt"
import "core:os"
import "pkgs:dotenv"

main :: proc() {
	_ = dotenv.load() // reads "./.env"; missing file is silently ignored
	fmt.println(os.get_env("PORT", context.allocator))
}
```

See [`examples/basic`](examples/basic) for a runnable example
(`odin run examples/basic`).

## API

All procs live in package `dotenv`:

| Proc | Description |
| ---- | ----------- |
| `load(path := ".env", override := false) -> (applied: int, err: Error)` | Read the file and export every variable into the process environment. Existing variables are kept unless `override` is set. Returns how many were exported. |
| `overload(path := ".env")` | `load` with `override` enabled: file values always win. |
| `must_load(path := ".env", override := false) -> int` | `load` that panics when the file cannot be loaded. Use when the file is required. |
| `read(path, allocator := context.allocator) -> (map[string]string, Error)` | Load and parse without touching the environment. Free the result with `destroy`. |
| `parse(content, allocator := context.allocator) -> map[string]string` | Parse `.env`-formatted text. Free the result with `destroy`. |
| `apply(values, override := false) -> (applied: int, err: Error)` | Export a map into the environment, honoring `override`. |
| `destroy(values, allocator := context.allocator)` | Free a map returned by `parse`/`read`. |

`Error` is `None`, `File_Not_Found` (unreadable file), or `Set_Env_Failed`.
`load` on a missing file returns `(0, .File_Not_Found)`, so treating `.env`
as optional is just `_ = dotenv.load()`.

## File format

One `KEY=VALUE` pair per line:

```env
# full-line comment
PORT=8080
export HOST=localhost          # optional `export` prefix
GREETING="hello world"         # double quotes: escapes + expansion
LITERAL='no $expansion \n'     # single quotes and backticks are literal
UNQUOTED=some value # comment  # trailing ` #` is stripped when unquoted
EMPTY=
URL="https://${HOST}:${PORT}"  # $VAR / ${VAR} expand from earlier entries,
FALLBACK="${MISSING:-default}" # then the environment (:- / - defaults ok)
```

Rules:

- Blank lines and lines without `=` are ignored.
- Keys must match `[A-Za-z_][A-Za-z0-9_]*`; anything else is ignored.
- Double-quoted values may span multiple lines and understand
  `\n \r \t \b \f \v \0 \\ \" \' \$` and backslash-backtick.
- A `#` starting a comment must be at line start or follow a space/tab,
  so `PASS=abc#123` keeps its `#`.
- Files may use LF or CRLF line endings and may start with a BOM.

## Testing

```sh
odin test tests/
```

The suite covers parsing, quoting, comments, expansion, overriding, and
file loading (24 tests, tracked for memory leaks).
