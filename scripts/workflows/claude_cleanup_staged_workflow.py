"""
Windows Claude Cleanup Toolkit - Reusable Staged Multi-Agent Workflow (Stages D-G)

Executed via run_workflow(ScriptPath=..., Args={...}).
Hard safety invariants:
- No real Claude cleanup, -Apply, npm uninstall, Remove-AppxPackage, VS Code live uninstall,
  HKCU/HKLM edits, ACL/ownership mutations, credential edits, or WSL modifications.
- No automatic git commit, git push, git reset, history rewrite, release publishing, or Public visibility change.
- Strict disjoint file ownership across parallel isolated Git worktrees inside tests/sandbox/worktrees/.
- Sequential integration, independent pro-model security gate, and sequential PS 5.1 -> PS 7 tests.
"""

import os

cfg = globals().get("args", {}) or {}
_ws = globals().get("WORKSPACES") or ()
TARGET_REPO = cfg.get("repo_path") or (_ws[0] if len(_ws) > 0 else os.getcwd())
STAGE_C_COMMIT = cfg.get("stage_c_commit", "b74072380e6fbc9f0cacd472ff717b0d0a184853")
RUN_TESTS = bool(cfg.get("run_tests", True))
START_PHASE = int(cfg.get("start_at_phase", 1))
WORKTREE_ROOT = TARGET_REPO.rstrip("\\/") + r"\tests\sandbox\worktrees"

APPROVED_MODIFIED_FILES = [
    "ClaudeCleanup.ps1",
    "tests/ClaudeCleanup.Tests.ps1",
    "README.md",
    "README_zh-CN.md",
    ".gitignore",
    "PLAN.md",
    "HANDOFF.md",
    "VERIFICATION.md",
]

APPROVED_NEW_FILES = [
    "scripts/workflows/claude_cleanup_staged_workflow.py",
    "skills/claude-cleanup/SKILL.md",
    "skills/claude-cleanup/references/permissions-and-risks.md",
    "skills/claude-cleanup/references/agent-installation.md",
    "tests/SkillPackage.Tests.ps1",
    "ClaudeCleanupLauncher.cmd",
    "scripts/ClaudeCleanupLauncher.ps1",
    "scripts/Install-ClaudeCleanup.ps1",
    "scripts/Update-ClaudeCleanup.ps1",
    "scripts/Uninstall-ClaudeCleanup.ps1",
    "docs/gui-evaluation.md",
    "tests/ToolkitInstall.Tests.ps1",
    "docs/CLI-Reference.md",
    "docs/Launcher-and-Install.md",
    "docs/Agent-Skill-Guide.md",
    "docs/Uninstallation-Guide.md",
    "docs/Troubleshooting-and-Compatibility.md",
    "docs/examples/AUDIT.sample.md",
    "docs/examples/CLEANUP-PLAN.sample.md",
    "docs/examples/VERIFICATION.sample.md",
    "SECURITY.md",
    "CONTRIBUTING.md",
    "CHANGELOG.md",
    "LICENSE",
    "NOTICE",
    ".github/workflows/ci.yml",
    "scripts/New-ReleasePackage.ps1",
    "tests/ToolkitCiChecks.Tests.ps1",
]

PARALLEL_TRACKS = [
    {
        "track": "StageD-CrossAgent-Skill",
        "model": "inherit",
        "branch": "wf/stage-d-skill",
        "worktree_dir": WORKTREE_ROOT + r"\stage-d-skill",
        "owned_files": [
            "skills/claude-cleanup/SKILL.md",
            "skills/claude-cleanup/references/permissions-and-risks.md",
            "skills/claude-cleanup/references/agent-installation.md",
            "tests/SkillPackage.Tests.ps1",
        ],
        "goal": (
            "Create the canonical cross-agent Skill package compatible with Codex CLI, "
            "Antigravity CLI, Gemini CLI, and Claude Code using one shared skills/claude-cleanup/SKILL.md. "
            "Must invoke ClaudeCleanup.ps1 directly (zero duplicated deletion code), default to read-only -Audit, "
            "require explicit plan SHA-256 + per-target authorization before -Apply, never recommend -ExecutionPolicy Bypass, "
            "keep REA strictly optional dev-only, document manual/user-scoped install & uninstall cleanly in references/, "
            "and test skill frontmatter, discovery structure, and non-destructive validation in tests/SkillPackage.Tests.ps1 "
            "(using tests/sandbox/skill/ inside your worktree only if fixtures are created, cleaned up in finally; "
            "document any live CLI discovery checks not run)."
        ),
    },
    {
        "track": "StageE-Launcher-Installer",
        "model": "inherit",
        "branch": "wf/stage-e-launcher-installer",
        "worktree_dir": WORKTREE_ROOT + r"\stage-e-launcher-installer",
        "owned_files": [
            "ClaudeCleanupLauncher.cmd",
            "scripts/ClaudeCleanupLauncher.ps1",
            "scripts/Install-ClaudeCleanup.ps1",
            "scripts/Update-ClaudeCleanup.ps1",
            "scripts/Uninstall-ClaudeCleanup.ps1",
            "docs/gui-evaluation.md",
            "tests/ToolkitInstall.Tests.ps1",
        ],
        "goal": (
            "Create: (1) ClaudeCleanupLauncher.cmd + scripts/ClaudeCleanupLauncher.ps1 minimal menu launcher "
            "(Audit / Plan / View Reports / Verify / Help / Exit + non-interactive -Action/-Exit smoke mode for CI tests; "
            "NO automatic -Apply execution, NO -ExecutionPolicy Bypass, NO auto-UAC elevation, works without any AI agent); "
            "(2) user-scoped scripts/Install-ClaudeCleanup.ps1, scripts/Update-ClaudeCleanup.ps1, and "
            "scripts/Uninstall-ClaudeCleanup.ps1 supporting independent toolkit install/update/uninstall AND optional "
            "explicit Skill install/uninstall strictly separated from Claude application removal; "
            "(3) docs/gui-evaluation.md evaluating optional future GUI thin wrapper feasibility; "
            "(4) tests/ToolkitInstall.Tests.ps1 validating launcher startup plus install->update->uninstall inside "
            "tests/sandbox/install-target/ and tests/sandbox/install/ inside your worktree only, cleaned up in finally."
        ),
    },
    {
        "track": "StageF-Bilingual-Docs",
        "model": "flash",
        "branch": "wf/stage-f-docs",
        "worktree_dir": WORKTREE_ROOT + r"\stage-f-docs",
        "owned_files": [
            "docs/CLI-Reference.md",
            "docs/Launcher-and-Install.md",
            "docs/Agent-Skill-Guide.md",
            "docs/Uninstallation-Guide.md",
            "docs/Troubleshooting-and-Compatibility.md",
            "docs/examples/AUDIT.sample.md",
            "docs/examples/CLEANUP-PLAN.sample.md",
            "docs/examples/VERIFICATION.sample.md",
            "SECURITY.md",
            "CONTRIBUTING.md",
            "CHANGELOG.md",
            "LICENSE",
            "NOTICE",
        ],
        "goal": (
            "Author sanitized project documentation, sample reports, and governance files: "
            "docs/CLI-Reference.md, docs/Launcher-and-Install.md, docs/Agent-Skill-Guide.md, "
            "docs/Uninstallation-Guide.md, docs/Troubleshooting-and-Compatibility.md, sanitized docs/examples/*.sample.md "
            "(zero local usernames, SIDs, secrets, or real host audit data), SECURITY.md, CONTRIBUTING.md, CHANGELOG.md, "
            "MIT LICENSE (after verifying clean-room Windows PowerShell implementation with zero third-party runtime dependencies), "
            "and NOTICE (documenting zero bundled third-party code, clean-room Windows design inspired conceptually by "
            "suyuan2022/claude-cleanup without porting backup/trash/identity-rotation code, and non-affiliation with Anthropic). "
            "Include clear Simplified Chinese and English navigation/bilingual alignment cues where helpful, accurately distinguishing implemented vs Planned features."
        ),
    },
    {
        "track": "StageF-Tests-And-CI",
        "model": "inherit",
        "branch": "wf/stage-f-ci",
        "worktree_dir": WORKTREE_ROOT + r"\stage-f-ci",
        "owned_files": [
            ".github/workflows/ci.yml",
            "scripts/New-ReleasePackage.ps1",
            "tests/ToolkitCiChecks.Tests.ps1",
        ],
        "goal": (
            "Create: (1) .github/workflows/ci.yml running Windows PowerShell 5.1 and PowerShell 7 test jobs cleanly "
            "on windows-latest (syntax/parse checks, full non-destructive test suites, link/privacy checks, visible reporting of "
            "Skipped and NotExecuted without counting them as Passed); "
            "(2) scripts/New-ReleasePackage.ps1 creating a sanitized release ZIP and SHA256SUMS.txt defaulting to dist/ "
            "(or caller -OutputDirectory), strictly excluding .git/, AGENTS.md, GOAL.md, PLAN.md, HANDOFF.md, AUDIT.md, "
            "CLEANUP-PLAN.md, VERIFICATION.md, dist/, tests/sandbox/, credentials, and personal logs; "
            "(3) tests/ToolkitCiChecks.Tests.ps1 validating CI workflow YAML invariants, release packaging exclusions, and "
            "SHA-256 verification strictly inside tests/sandbox/ci/ and tests/sandbox/release/ inside your worktree only, cleaned up in finally."
        ),
    },
]

DISCOVERY_SCHEMA = {
    "type": "object",
    "properties": {
        "branch": {"type": "string"},
        "head_commit": {"type": "string"},
        "stage_c_verified": {"type": "boolean"},
        "working_tree_clean_of_staged_temp_docs": {"type": "boolean"},
        "ignored_files": {"type": "array", "items": {"type": "string"}},
        "blockers": {"type": "array", "items": {"type": "string"}},
    },
    "required": [
        "branch",
        "head_commit",
        "stage_c_verified",
        "working_tree_clean_of_staged_temp_docs",
        "ignored_files",
        "blockers",
    ],
}

WORKTREE_PREP_SCHEMA = {
    "type": "object",
    "properties": {
        "worktrees": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "track": {"type": "string"},
                    "branch": {"type": "string"},
                    "path": {"type": "string"},
                    "within_approved_sandbox": {"type": "boolean"},
                },
                "required": ["track", "branch", "path", "within_approved_sandbox"],
            },
        },
        "all_verified": {"type": "boolean"},
    },
    "required": ["worktrees", "all_verified"],
}

TRACK_SCHEMA = {
    "type": "object",
    "properties": {
        "track": {"type": "string"},
        "isolated_workspace_path": {"type": "string"},
        "isolated_branch": {"type": "string"},
        "artifacts": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "content": {"type": "string"},
                },
                "required": ["path", "content"],
            },
        },
        "tests": {
            "type": "object",
            "properties": {
                "passed": {"type": "integer"},
                "failed": {"type": "integer"},
                "skipped": {"type": "integer"},
                "not_executed": {"type": "integer"},
                "blocked": {"type": "integer"},
                "notes": {"type": "string"},
            },
            "required": ["passed", "failed", "skipped", "not_executed", "blocked", "notes"],
        },
        "risks": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["track", "isolated_workspace_path", "isolated_branch", "artifacts", "tests", "risks"],
}

INTEGRATION_SCHEMA = {
    "type": "object",
    "properties": {
        "applied_files": {"type": "array", "items": {"type": "string"}},
        "rejected_out_of_scope_files": {"type": "array", "items": {"type": "string"}},
        "shared_engine_changes": {"type": "array", "items": {"type": "string"}},
        "docs_synced": {"type": "array", "items": {"type": "string"}},
        "worktrees_cleaned": {"type": "boolean"},
        "notes": {"type": "string"},
    },
    "required": [
        "applied_files",
        "rejected_out_of_scope_files",
        "shared_engine_changes",
        "docs_synced",
        "worktrees_cleaned",
        "notes",
    ],
}

SECURITY_SCHEMA = {
    "type": "object",
    "properties": {
        "verdict": {"type": "string", "enum": ["APPROVED", "BLOCKED"]},
        "findings": {"type": "array", "items": {"type": "string"}},
        "invariants_checked": {"type": "array", "items": {"type": "string"}},
        "remaining_risks": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["verdict", "findings", "invariants_checked", "remaining_risks"],
}

TEST_COUNTS_SCHEMA = {
    "type": "object",
    "properties": {
        "suite": {"type": "string"},
        "passed": {"type": "integer"},
        "failed": {"type": "integer"},
        "skipped": {"type": "integer"},
        "not_executed": {"type": "integer"},
        "blocked": {"type": "integer"},
        "skipped_details": {"type": "array", "items": {"type": "string"}},
        "not_executed_details": {"type": "array", "items": {"type": "string"}},
    },
    "required": [
        "suite",
        "passed",
        "failed",
        "skipped",
        "not_executed",
        "blocked",
        "skipped_details",
        "not_executed_details",
    ],
}

FINAL_VERIFY_SCHEMA = {
    "type": "object",
    "properties": {
        "ps51_suites": {"type": "array", "items": TEST_COUNTS_SCHEMA},
        "ps7_suites": {"type": "array", "items": TEST_COUNTS_SCHEMA},
        "defects_fixed_in_scope": {"type": "array", "items": {"type": "string"}},
        "launcher_smoke": {"type": "string"},
        "skill_validation": {"type": "string"},
        "release_package": {
            "type": "object",
            "properties": {
                "zip_path": {"type": "string"},
                "checksum_file": {"type": "string"},
                "sha256_verified": {"type": "boolean"},
                "excluded_temp_and_sensitive_verified": {"type": "boolean"},
            },
            "required": [
                "zip_path",
                "checksum_file",
                "sha256_verified",
                "excluded_temp_and_sensitive_verified",
            ],
        },
        "privacy_and_links": {"type": "string"},
        "management_docs_updated": {"type": "array", "items": {"type": "string"}},
        "git_status_summary": {"type": "string"},
        "acceptance_verdict": {"type": "string"},
        "remaining_risks": {"type": "array", "items": {"type": "string"}},
    },
    "required": [
        "ps51_suites",
        "ps7_suites",
        "defects_fixed_in_scope",
        "launcher_smoke",
        "skill_validation",
        "release_package",
        "privacy_and_links",
        "management_docs_updated",
        "git_status_summary",
        "acceptance_verdict",
        "remaining_risks",
    ],
}

integration = None
if START_PHASE <= 3:
    # Phase 1: Read-only baseline & Stage C verification
    phase("Phase 1: Read-Only Discovery & Stage C Baseline Verification")
    discovery = await agent(
        prompt=(
            f"Read-only baseline check in {TARGET_REPO}. Read AGENTS.md, GOAL.md, PLAN.md, HANDOFF.md, "
            "and VERIFICATION.md. Run read-only `git branch --show-current`, `git rev-parse HEAD`, "
            "`git status --short --ignored`, and `git log -n 2 --oneline` (with $env:GIT_CONFIG_GLOBAL='NUL'). "
            f"Verify base commit matches expected Stage C baseline {STAGE_C_COMMIT} and AGENTS.md/GOAL.md/HANDOFF.md/PLAN.md "
            "are NOT staged in Git index. Do NOT write, commit, push, or reset anything."
        ),
        schema=DISCOVERY_SCHEMA,
        role="StageC-Baseline-Discovery",
        type_name="research",
        workspace="inherit",
        model="flash",
    )
    log("Phase 1 discovery:", discovery)
    if discovery["blockers"]:
        raise RuntimeError(f"Phase 1 baseline blockers detected: {discovery['blockers']}")

    # Phase 1b: Create and verify isolated Git worktrees inside approved tests/sandbox/worktrees/
    phase("Phase 1b: Verify & Prepare Isolated Worktrees")
    worktree_specs = [
        {"track": t["track"], "branch": t["branch"], "path": t["worktree_dir"]}
        for t in PARALLEL_TRACKS
    ]
    prep = await agent(
        prompt=(
            f"Prepare isolated Git worktrees inside {WORKTREE_ROOT} (which is strictly inside approved gitignored "
            f"{TARGET_REPO}\\tests\\sandbox\\). First verify every path starts with `{WORKTREE_ROOT}` before creating it.\n"
            f"For each spec in {worktree_specs}:\n"
            f"With $env:GIT_CONFIG_GLOBAL='NUL' in {TARGET_REPO}, remove any stale directory at spec.path if leftover, "
            f"and run `git worktree add -B <branch> <path> {STAGE_C_COMMIT}`.\n"
            "Run `git worktree list` to verify all 4 worktrees are checked out cleanly at the Stage C commit "
            "without modifying main or any existing files."
        ),
        schema=WORKTREE_PREP_SCHEMA,
        role="Worktree-Provisioner",
        type_name="self",
        workspace="inherit",
        model="inherit",
    )
    log("Phase 1b worktree prep:", prep)
    if not prep["all_verified"]:
        raise RuntimeError(f"Worktree boundary verification failed: {prep}")

    # Phase 2: Parallel isolated worktree implementation for disjoint Stages D/E/F work
    phase("Phase 2: Parallel Independent Implementation (Isolated Worktrees)")


    def build_track_agent(spec):
        owned = ", ".join(spec["owned_files"])
        wt = spec["worktree_dir"]
        return agent(
            prompt=(
                f"Track: {spec['track']}\n"
                f"YOUR ISOLATED GIT WORKTREE IS: `{wt}` (branch `{spec['branch']}`).\n"
                f"Read `{TARGET_REPO}\\AGENTS.md` and `{TARGET_REPO}\\GOAL.md` read-only first, then perform ALL edits, "
                f"file creations, and test commands STRICTLY inside `{wt}`!\n"
                f"NEVER write to `{TARGET_REPO}` root or any other track's worktree.\n"
                f"STRICT OWNED FILES (create/modify ONLY these relative paths inside `{wt}`): {owned}.\n"
                f"Task: {spec['goal']}\n"
                "Hard Safety Rules:\n"
                "- Never modify ClaudeCleanup.ps1, tests/ClaudeCleanup.Tests.ps1, README.md, README_zh-CN.md, "
                ".gitignore, GOAL.md, PLAN.md, HANDOFF.md, AGENTS.md, or global agent configs (~/.codex, ~/.agents, ~/.gemini, ~/.claude).\n"
                "- Never run real -Apply, npm uninstall, Remove-AppxPackage, VS Code live uninstall, HKCU/HKLM edits, ACL edits, or WSL edits.\n"
                f"- Keep all temporary test fixtures inside `{wt}\\tests\\sandbox\\` and remove them in finally.\n"
                "- Use PowerShell 5.1 AND PowerShell 7 compatible syntax (Set-StrictMode safe, ASCII or UTF-8 clean).\n"
                "- Never git commit, git push, or touch real user installations.\n"
                "- Return isolated_workspace_path (the exact worktree path), isolated_branch, every owned file's relative path + "
                "exact UTF-8 content in `artifacts`, and honest test counts (never count Skipped/NotExecuted/Blocked as Passed)."
            ),
            schema=TRACK_SCHEMA,
            role=spec["track"],
            type_name="self",
            workspace="inherit",
            model=spec["model"],
        )


    track_results = await parallel(PARALLEL_TRACKS, build_track_agent)
    for tr in track_results:
        log(f"Track {tr['track']} ({tr['isolated_branch']} @ {tr['isolated_workspace_path']}):", tr["tests"])

    # Phase 3: Sequential integration into primary workspace + cleanup of temporary worktrees
    phase("Phase 3: Sequential Integration & Shared Docs Sync")
    integration = await agent(
        prompt=(
            f"Sequential Integration in {TARGET_REPO}. Inspect all Phase 2 outputs:\n{track_results}\n\n"
            f"STRICT APPROVED NEW FILE ALLOWLIST:\n{APPROVED_NEW_FILES}\n"
            f"STRICT APPROVED MODIFIED FILE ALLOWLIST:\n{APPROVED_MODIFIED_FILES}\n\n"
            "Requirements:\n"
            "1. Verify every returned artifact path in Phase 2 is strictly within that track's owned_files AND "
            "APPROVED_NEW_FILES; reject and list any unexpected paths in `rejected_out_of_scope_files` without writing them.\n"
            "2. Copy/write the validated Track 1-4 files cleanly into {TARGET_REPO} (preferring copying verbatim from their verified "
            "worktree paths when identical to artifacts).\n"
            "3. Cleanly remove the 4 temporary worktrees (`git worktree remove --force <path>` + `git worktree prune`) inside "
            f"`{WORKTREE_ROOT}` and remove `{WORKTREE_ROOT}` if empty so `tests/sandbox/` is clean before Phase 5 (delete temporary `wf/*` branches with `git branch -D` only).\n"
            "4. Update .gitignore to ignore `dist/` (only minimal clean ignore addition).\n"
            "5. Only modify ClaudeCleanup.ps1 if strictly necessary for launcher/Skill compatibility (prefer zero changes; "
            "zero relaxation of safety invariants). Update README.md and README_zh-CN.md cleanly so language links, Stage D-F "
            "features, quickstart, Skill, Launcher, Installer/Updater/Uninstaller, Security/Contributing/Changelog/License/Notice links "
            "work and all paths exist. Maintain accurate distinction between implemented capabilities and non-verified live operations.\n"
            "6. Do NOT touch AGENTS.md or GOAL.md, and leave PLAN.md / HANDOFF.md / VERIFICATION.md for Phase 5.\n"
            "7. Do NOT git commit, git push, reset HEAD, or publish releases."
        ),
        schema=INTEGRATION_SCHEMA,
        role="Sequential-Integrator",
        type_name="self",
        workspace="inherit",
        model="pro",
    )
    log("Phase 3 integration:", integration)
    if integration["rejected_out_of_scope_files"]:
        raise RuntimeError(f"Out-of-scope paths rejected during integration: {integration['rejected_out_of_scope_files']}")
else:
    log("Resuming workflow at phase:", START_PHASE)

# Phase 4: Independent Security Verifier (strong reasoning model, read-only audit)
phase("Phase 4: Independent Security Verification")
security_prompt_context = (
    f"Inspect integrated workspace files in {TARGET_REPO} (approved new: {APPROVED_NEW_FILES}; approved modified: {APPROVED_MODIFIED_FILES})."
    if integration is None
    else f"Inspect all integrated files and scripts:\n{integration}"
)
security_review = await agent(
    prompt=(
        f"Independent Security Review (read-only) in {TARGET_REPO}. {security_prompt_context}\n\n"
        "Verify strictly:\n"
        "- ClaudeCleanup.ps1 still has zero Remove-Item or RegDeleteKeyW fallback and full OwnerSid enforcement.\n"
        "- Zero -ExecutionPolicy Bypass or auto-UAC elevation in ClaudeCleanupLauncher.cmd, Launcher, Install/Update/Uninstall scripts, Skill, or ci.yml.\n"
        "- Skill (skills/claude-cleanup/SKILL.md & references) defaults to read-only -Audit, delegates strictly to ClaudeCleanup.ps1, "
        "never duplicates deletion code, requires explicit SHA-256 + per-target authorization before -Apply, keeps REA optional dev-only.\n"
        "- Install/Update/Uninstall strictly operate user-scoped, separate toolkit/Skill removal from Claude application removal, and tests touch only tests/sandbox/.\n"
        "- New-ReleasePackage.ps1 strictly excludes .git/, AGENTS.md, GOAL.md, PLAN.md, HANDOFF.md, AUDIT.md, CLEANUP-PLAN.md, VERIFICATION.md, dist/, tests/sandbox/, secrets.\n"
        "- LICENSE and NOTICE accurately reflect zero bundled third-party code, clean-room implementation, and attribution.\n"
        "- Zero personal paths, SIDs, credentials, or real host audit data anywhere in repo or docs/examples/.\n"
        "Return APPROVED only if zero security blockers exist; otherwise return BLOCKED with exact findings."
    ),
    schema=SECURITY_SCHEMA,
    role="Independent-Security-Verifier",
    type_name="research",
    workspace="inherit",
    model="pro",
)
log("Phase 4 security verdict:", security_review)
if security_review["verdict"] != "APPROVED":
    raise RuntimeError(f"Security gate BLOCKED workflow: {security_review['findings']}")

# Phase 5: Sequential Stage G Testing (PS 5.1 -> PS 7), Release Package Build, and Management Updates
phase("Phase 5: Sequential Dual-PowerShell Verification, Release Packaging & Handoff Update")
final_verification = await agent(
    prompt=(
        f"Sequential Final Non-Destructive Validation & Handoff Update in {TARGET_REPO} (RUN_TESTS={RUN_TESTS}).\n"
        "1. Parse/syntax check all .ps1 files in both Windows PowerShell 5.1 and PowerShell 7.\n"
        "2. Run ALL 4 test suites SEQUENTIALLY (NEVER concurrently, because tests/sandbox/ is shared):\n"
        "   In powershell.exe (-NoProfile): tests/ClaudeCleanup.Tests.ps1, tests/SkillPackage.Tests.ps1, tests/ToolkitInstall.Tests.ps1, tests/ToolkitCiChecks.Tests.ps1.\n"
        "   In pwsh.exe (-NoProfile): tests/ClaudeCleanup.Tests.ps1, tests/SkillPackage.Tests.ps1, tests/ToolkitInstall.Tests.ps1, tests/ToolkitCiChecks.Tests.ps1.\n"
        "   Report exact Passed, Failed, Skipped, NotExecuted, and Blocked counts separately without counting Skipped/NotExecuted/Blocked as Passed.\n"
        "3. Run launcher non-interactive smoke test, Skill static validation, and execute scripts/New-ReleasePackage.ps1 "
        "generating sanitized ZIP + SHA256SUMS.txt inside dist/, then verify SHA-256 checksum matches and ZIP excludes AGENTS.md, GOAL.md, PLAN.md, HANDOFF.md, AUDIT.md, CLEANUP-PLAN.md, VERIFICATION.md, dist/, tests/sandbox/.\n"
        "4. Fix ONLY genuine bugs strictly within APPROVED_MODIFIED_FILES / APPROVED_NEW_FILES if needed; if any code/script is edited during Phase 5, record in `defects_fixed_in_scope` and re-run affected tests in BOTH PS 5.1 and PS 7.\n"
        "5. Check relative Markdown links across README.md, README_zh-CN.md, docs/*, skills/*, GOAL.md, PLAN.md, HANDOFF.md, AGENTS.md and run privacy pattern scan (C:\\Users\\, S-1-5-21-, sk-ant-, AKIA).\n"
        "6. Update PLAN.md, HANDOFF.md, and local VERIFICATION.md with exact observed test counts, dist/ package details, remaining risks, and git status (do NOT commit, push, reset, or publish).\n"
        "7. Ensure tests/sandbox/ is cleanly removed on exit."
    ),
    schema=FINAL_VERIFY_SCHEMA,
    role="Sequential-QA-And-Handoff",
    type_name="self",
    workspace="inherit",
    model="pro",
)
log("Phase 5 verification:", final_verification)

# Phase 6: Post-fix independent security sign-off if Phase 5 fixed any defect
if final_verification["defects_fixed_in_scope"]:
    phase("Phase 6: Post-Fix Security Re-Verification")
    recheck = await agent(
        prompt=(
            f"Read-only Security Re-Check in {TARGET_REPO} after Phase 5 defects fixed: "
            f"{final_verification['defects_fixed_in_scope']}. Verify all invariants remain APPROVED."
        ),
        schema=SECURITY_SCHEMA,
        role="PostFix-Security-ReVerifier",
        type_name="research",
        workspace="inherit",
        model="pro",
    )
    log("Phase 6 security re-check:", recheck)
    if recheck["verdict"] != "APPROVED":
        raise RuntimeError(f"Post-fix security re-check BLOCKED: {recheck['findings']}")

log("Workflow complete without errors.")
