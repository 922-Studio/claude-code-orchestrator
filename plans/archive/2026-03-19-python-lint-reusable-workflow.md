# Plan: Reusable Python Lint Workflow + Node.js 20 Deprecation Fix

- **Date**: 2026-03-19
- **Status**: DONE (2026-03-19)
- **Project(s)**: workflows, HomeAPI, HomeAuth, HomeCollector
- **Goal**: Extract the inline "Lint (ruff + mypy)" job into a reusable workflow in `922-Studio/workflows`, fix the Node.js 20 deprecation warning, and replace all inline lint jobs with calls to the new reusable workflow.

## Context

Read these files before proceeding:
- `projects/workflows.md` — reusable workflows project mapping (if exists)
- `server.md` — server infrastructure reference
- Existing reusable workflow for pattern reference: `/Users/gregor/dev/922/workflows/.github/workflows/python-tests.yml`

### Problem Analysis

**3 projects** have identical inline lint jobs using deprecated actions:
- **HomeAPI** (`/Users/gregor/dev/922/HomeAPI/.github/workflows/deploy.yml:28-40`)
- **HomeAuth** (`/Users/gregor/dev/922/HomeAuth/.github/workflows/deploy.yml:28-40`)
- **HomeCollector** (`/Users/gregor/dev/922/HomeCollector/.github/workflows/deploy.yml:28-40`)

Each inline lint job:
1. Uses `actions/checkout@v4.2.2` (Node.js 20 — deprecated, forced to Node.js 24 from June 2, 2026)
2. Uses `actions/setup-python@v5.6.0` (Node.js 20 — deprecated)
3. Installs ruff + mypy (+ optional extras like pydantic)
4. Runs `ruff check`, optionally `ruff format --check`, and `mypy`

**Differences between projects:**

| Parameter | HomeAPI | HomeAuth | HomeCollector |
|---|---|---|---|
| Python version | 3.13 | 3.12 | 3.13 |
| Install command | `pip install ruff mypy pydantic -q` | `pip install -r requirements.txt ruff mypy -q` | `pip install ruff mypy pydantic -q` |
| Source directory | `app/` | `app/` | `app/` |
| ruff format check | Yes | No | Yes |
| runs-on | `ubuntu-latest` | `ubuntu-latest` | `ubuntu-latest` |
| if condition | (none) | `${{ always() }}` | (none) |

## Steps

### Step 1: Create reusable `python-lint.yml` workflow

- **Project**: workflows
- **Directory**: `/Users/gregor/dev/922/workflows/.github/workflows/`
- **Parallel with**: —
- **Description**: Create a new reusable workflow `python-lint.yml` following the same pattern as `python-tests.yml`. Use updated actions that support Node.js 24.
- **Context files to read**:
  - `/Users/gregor/dev/922/workflows/.github/workflows/python-tests.yml` — pattern reference for reusable workflow structure
- **New file**: `/Users/gregor/dev/922/workflows/.github/workflows/python-lint.yml`
- **Workflow inputs**:

```yaml
name: Python Lint (ruff + mypy)

on:
  workflow_call:
    inputs:
      python_version:
        required: false
        type: string
        default: '3.13'
        description: 'Python version to use'
      source_directory:
        required: false
        type: string
        default: 'app/'
        description: 'Directory to lint (passed to ruff and mypy)'
      install_command:
        required: false
        type: string
        default: 'pip install ruff mypy -q'
        description: 'Command to install linting dependencies (e.g. include requirements.txt for mypy type stubs)'
      ruff_format_check:
        required: false
        type: boolean
        default: true
        description: 'Run ruff format --check in addition to ruff check'
      mypy_args:
        required: false
        type: string
        default: '--ignore-missing-imports'
        description: 'Extra arguments to pass to mypy'
      runs_on:
        required: false
        type: string
        default: 'ubuntu-latest'
        description: 'Runner label'

jobs:
  lint:
    name: Lint (ruff + mypy)
    runs-on: ${{ inputs.runs_on }}
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-python@v6
        with:
          python-version: ${{ inputs.python_version }}
      - name: Install dependencies
        run: ${{ inputs.install_command }}
      - name: Ruff check
        run: ruff check ${{ inputs.source_directory }}
      - name: Ruff format check
        if: ${{ inputs.ruff_format_check }}
        run: ruff format --check ${{ inputs.source_directory }}
      - name: Mypy
        run: mypy ${{ inputs.source_directory }} ${{ inputs.mypy_args }}
```

- **Key decisions**:
  - `actions/checkout@v5` and `actions/setup-python@v6` — both support Node.js 24, fixing the deprecation warning
  - Parameterized all differences between the 3 projects
  - Kept `runs-on` configurable (defaults to `ubuntu-latest` to match current behavior)
- **Acceptance criteria**:
  - [ ] File created at `workflows/.github/workflows/python-lint.yml`
  - [ ] Uses `actions/checkout@v5` (not v4)
  - [ ] Uses `actions/setup-python@v6` (not v5)
  - [ ] All inputs have sensible defaults matching the most common usage
  - [ ] Workflow syntax is valid (`actionlint` passes if available)

### Step 2: Replace inline lint job in HomeAPI

- **Project**: HomeAPI
- **Directory**: `/Users/gregor/dev/922/HomeAPI/.github/workflows/`
- **Parallel with**: Step 3, Step 4
- **Description**: Replace the inline `lint` job (lines 28-40) with a call to the new reusable workflow.
- **Context files to read**:
  - `/Users/gregor/dev/922/HomeAPI/.github/workflows/deploy.yml` — current workflow
- **Change**: Replace lines 28-40 with:

```yaml
  lint:
    needs: version
    name: Lint (ruff + mypy)
    uses: 922-Studio/workflows/.github/workflows/python-lint.yml@main
    with:
      python_version: '3.13'
      install_command: 'pip install ruff mypy pydantic -q'
      ruff_format_check: true
```

- **Acceptance criteria**:
  - [ ] Inline lint job replaced with reusable workflow call
  - [ ] No `actions/checkout@v4.2.2` or `actions/setup-python@v5.6.0` references remain
  - [ ] All lint parameters preserved (python 3.13, pydantic extra, format check enabled)
  - [ ] `needs: version` dependency preserved

### Step 3: Replace inline lint job in HomeAuth

- **Project**: HomeAuth
- **Directory**: `/Users/gregor/dev/922/HomeAuth/.github/workflows/`
- **Parallel with**: Step 2, Step 4
- **Description**: Replace the inline `lint` job (lines 28-40) with a call to the new reusable workflow.
- **Context files to read**:
  - `/Users/gregor/dev/922/HomeAuth/.github/workflows/deploy.yml` — current workflow
- **Change**: Replace lines 28-40 with:

```yaml
  lint:
    needs: version
    name: Lint (ruff + mypy)
    if: ${{ always() }}
    uses: 922-Studio/workflows/.github/workflows/python-lint.yml@main
    with:
      python_version: '3.12'
      install_command: 'pip install -r requirements.txt ruff mypy -q'
      ruff_format_check: false
```

- **Acceptance criteria**:
  - [ ] Inline lint job replaced with reusable workflow call
  - [ ] `if: ${{ always() }}` preserved (HomeAuth-specific)
  - [ ] Python version stays at 3.12
  - [ ] `requirements.txt` included in install command (needed for mypy type stubs)
  - [ ] `ruff_format_check: false` (HomeAuth doesn't use format check currently)

### Step 4: Replace inline lint job in HomeCollector

- **Project**: HomeCollector
- **Directory**: `/Users/gregor/dev/922/HomeCollector/.github/workflows/`
- **Parallel with**: Step 2, Step 3
- **Description**: Replace the inline `lint` job (lines 28-40) with a call to the new reusable workflow.
- **Context files to read**:
  - `/Users/gregor/dev/922/HomeCollector/.github/workflows/deploy.yml` — current workflow
- **Change**: Replace lines 28-40 with:

```yaml
  lint:
    needs: version
    name: Lint (ruff + mypy)
    uses: 922-Studio/workflows/.github/workflows/python-lint.yml@main
    with:
      python_version: '3.13'
      install_command: 'pip install ruff mypy pydantic -q'
      ruff_format_check: true
```

- **Acceptance criteria**:
  - [ ] Inline lint job replaced with reusable workflow call
  - [ ] All lint parameters preserved (python 3.13, pydantic extra, format check enabled)
  - [ ] `needs: version` dependency preserved

### Step 5: Verify and push

- **Project**: All
- **Directory**: All affected repos
- **Parallel with**: —
- **Description**: Validate all workflow files and push changes. The `workflows` repo must be pushed first since the other repos reference it via `@main`.
- **Acceptance criteria**:
  - [ ] `workflows` repo pushed to main first
  - [ ] HomeAPI, HomeAuth, HomeCollector pushed after
  - [ ] No Node.js 20 deprecation warnings in subsequent pipeline runs
  - [ ] Lint jobs pass in all 3 projects

## Execution Overview

```
=== EXECUTION OVERVIEW ===

Wave 1:
  Step 1: Create python-lint.yml reusable workflow → workflows @ /Users/gregor/dev/922/workflows/
  Push workflows to main (must land first — callers reference @main)

Wave 2 (parallel, after wave 1):
  Step 2: Replace inline lint in HomeAPI    → HomeAPI @ /Users/gregor/dev/922/HomeAPI/
  Step 3: Replace inline lint in HomeAuth   → HomeAuth @ /Users/gregor/dev/922/HomeAuth/
  Step 4: Replace inline lint in HomeCollector → HomeCollector @ /Users/gregor/dev/922/HomeCollector/

Wave 3 (after wave 2):
  Step 5: Push all 3 consumer repos and verify pipelines
```

## Agent Prompts

### Step 1 Agent Prompt (workflows repo)
```
Read /Users/gregor/dev/922/workflows/.github/workflows/python-tests.yml for the reusable workflow pattern.
Create /Users/gregor/dev/922/workflows/.github/workflows/python-lint.yml with the content specified in the plan at /Users/gregor/dev/922/Planner/plans/2026-03-19-python-lint-reusable-workflow.md Step 1.
Commit with message: "feat: add reusable python-lint workflow (ruff + mypy)"
```

### Steps 2-4 Agent Prompt (consumer repos — run in parallel)
```
Read the plan at /Users/gregor/dev/922/Planner/plans/2026-03-19-python-lint-reusable-workflow.md.
Read the deploy.yml in this project's .github/workflows/ directory.
Replace the inline lint job with the reusable workflow call as specified in Step [N].
Commit with message: "refactor: use reusable python-lint workflow, fix Node.js 20 deprecation"
```

## Post-Execution Checklist
- [ ] All tests pass
- [ ] Pipeline green on all 4 repos
- [ ] No Node.js 20 deprecation warnings
- [ ] Zero inline lint jobs remaining (all use reusable workflow)
