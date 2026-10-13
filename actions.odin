package octodin

import "core:strings"

// This file covers the GitHub Actions API: workflows, runs, and jobs.

// Workflows_Envelope is the body of "list workflows".
Workflows_Envelope :: struct {
	total_count: int `json:"total_count"`,
	workflows:   []Workflow `json:"workflows"`,
}

destroy_workflows_envelope :: proc(e: ^Workflows_Envelope) {
	destroy_workflows(e.workflows)
	e^ = {}
}

// list_workflows lists the workflows of a repository.
list_workflows :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	opts: List_Options = {},
) -> (
	Workflows_Envelope,
	Response,
	Error,
) {
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts, c.allocator)
	base := _repo_sub(owner, repo, "/actions/workflows", c.allocator)
	defer delete(base)
	path := with_query(base, &q, c.allocator)
	defer delete(path)
	return get_into(c, path, Workflows_Envelope)
}

// get_workflow fetches a workflow by id or file name.
get_workflow :: proc(
	c: ^Client,
	owner, repo, workflow: string,
) -> (
	Workflow,
	Response,
	Error,
) {
	esc := url_escape(workflow, c.allocator)
	defer delete(esc)
	suffix := strings.concatenate({"/actions/workflows/", esc}, c.allocator)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return get_into(c, path, Workflow)
}

// List_Runs_Options filters workflow-run listings.
List_Runs_Options :: struct {
	using list: List_Options,
	actor:      string `json:"actor,omitempty"`,
	branch:     string `json:"branch,omitempty"`,
	event:      string `json:"event,omitempty"`,
	status:     string `json:"status,omitempty"`, // "queued", "in_progress", "completed", ...
}

// Runs_Envelope is the body of "list runs".
Runs_Envelope :: struct {
	total_count:   int `json:"total_count"`,
	workflow_runs: []Workflow_Run `json:"workflow_runs"`,
}

destroy_runs_envelope :: proc(e: ^Runs_Envelope) {
	destroy_workflow_runs(e.workflow_runs)
	e^ = {}
}

_list_runs_path :: proc(
	base: string,
	opts: List_Runs_Options,
	allocator := context.allocator,
) -> string {
	q := query_builder_make(allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts.list, allocator)
	query_add_string(&q, "actor", opts.actor, allocator)
	query_add_string(&q, "branch", opts.branch, allocator)
	query_add_string(&q, "event", opts.event, allocator)
	query_add_string(&q, "status", opts.status, allocator)
	return with_query(base, &q, allocator)
}

// list_repo_runs lists the workflow runs of a repository.
list_repo_runs :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	opts: List_Runs_Options = {},
) -> (
	Runs_Envelope,
	Response,
	Error,
) {
	base := _repo_sub(owner, repo, "/actions/runs", c.allocator)
	defer delete(base)
	path := _list_runs_path(base, opts, c.allocator)
	defer delete(path)
	return get_into(c, path, Runs_Envelope)
}

// list_workflow_runs lists the runs of one workflow.
list_workflow_runs :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	workflow: string,
	opts: List_Runs_Options = {},
) -> (
	Runs_Envelope,
	Response,
	Error,
) {
	esc := url_escape(workflow, c.allocator)
	defer delete(esc)
	suffix := strings.concatenate(
		{"/actions/workflows/", esc, "/runs"},
		c.allocator,
	)
	defer delete(suffix)
	base := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(base)
	path := _list_runs_path(base, opts, c.allocator)
	defer delete(path)
	return get_into(c, path, Runs_Envelope)
}

// get_run fetches a single workflow run by id.
get_run :: proc(
	c: ^Client,
	owner, repo: string,
	run_id: i64,
) -> (
	Workflow_Run,
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{"/actions/runs/", _itoa(int(run_id), context.temp_allocator)},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return get_into(c, path, Workflow_Run)
}

// rerun_run re-runs a workflow run.
rerun_run :: proc(
	c: ^Client,
	owner, repo: string,
	run_id: i64,
) -> (
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{
			"/actions/runs/",
			_itoa(int(run_id), context.temp_allocator),
			"/rerun",
		},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return post_raw(c, path)
}

// cancel_run cancels a workflow run.
cancel_run :: proc(
	c: ^Client,
	owner, repo: string,
	run_id: i64,
) -> (
	Response,
	Error,
) {
	suffix := strings.concatenate(
		{
			"/actions/runs/",
			_itoa(int(run_id), context.temp_allocator),
			"/cancel",
		},
		c.allocator,
	)
	defer delete(suffix)
	path := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(path)
	return post_raw(c, path)
}

// Jobs_Envelope is the body of "list jobs".
Jobs_Envelope :: struct {
	total_count: int `json:"total_count"`,
	jobs:        []Job `json:"jobs"`,
}

destroy_jobs_envelope :: proc(e: ^Jobs_Envelope) {
	destroy_jobs(e.jobs)
	e^ = {}
}

// list_run_jobs lists the jobs of a workflow run.
list_run_jobs :: proc(
	c: ^Client,
	owner: string,
	repo: string,
	run_id: i64,
	opts: List_Options = {},
) -> (
	Jobs_Envelope,
	Response,
	Error,
) {
	q := query_builder_make(c.allocator)
	defer query_builder_destroy(&q)
	apply_list_options(&q, opts, c.allocator)
	suffix := strings.concatenate(
		{
			"/actions/runs/",
			_itoa(int(run_id), context.temp_allocator),
			"/jobs",
		},
		c.allocator,
	)
	defer delete(suffix)
	base := _repo_sub(owner, repo, suffix, c.allocator)
	defer delete(base)
	path := with_query(base, &q, c.allocator)
	defer delete(path)
	return get_into(c, path, Jobs_Envelope)
}
