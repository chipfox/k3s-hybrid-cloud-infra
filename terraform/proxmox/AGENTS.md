# terraform/proxmox — AGENTS.md

## OVERVIEW

Proxmox Terraform root that provisions k3s VMs, generates Ansible inventory, and deploys ArgoCD — forming the first stage of the one-button deployment pipeline.

### Role in the Pipeline

`terraform apply` in this directory does three things in sequence:

1. **Provisions VMs** — Creates k3s server and agent VMs on Proxmox with cloud-init (packages, users, static IPs, qemu-guest-agent).
2. **Generates Ansible inventory** — Writes `../k3s-ansible/inventory.ini` with correct IPs and roles so Ansible can bootstrap k3s with zero manual edits.
3. **Deploys ArgoCD** — Installs ArgoCD via Helm chart into the k3s cluster. ArgoCD is configured with the gitops repo URL, admin password (bcrypt-hashed), and NodePort service. On first sync, ArgoCD's bootstrap Application picks up ApplicationSets from `gitops/` and auto-deploys all workloads.

After this stage + `ansible-playbook`, the cluster is fully operational with ArgoCD managing all application pods from git. No manual kubectl or UI steps.

## STRUCTURE

```
terraform/proxmox/
├── main.tf
├── variables.tf
├── locals.tf
├── outputs.tf
├── inventory.tf
├── inventory.tpl
├── cloud-init.tpl.yaml
├── CONFIGURATION_CHECKLIST.md
└── FIXES_APPLIED.md
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| VM resources | main.tf | k3s_server / k3s_agent definitions |
| Naming/IP/ID logic | locals.tf | k3st-* names, IP bases, VM ID bases |
| Input variables | variables.tf | Defaults + sensitive settings |
| Inventory output | inventory.tf + inventory.tpl | Writes ../k3s-ansible/inventory.ini |
| Cloud-init content | cloud-init.tpl.yaml | Packages + agent enablement only |
| Ops validation | CONFIGURATION_CHECKLIST.md | Must-follow verification |
| Historical fixes | FIXES_APPLIED.md | Root causes + resolution steps |

## CODE STYLE

- **Self-documenting**: Resource and variable names must make the code readable without comments or external docs. If `main.tf` isn't instantly understandable, simplify it.
- **Minimal**: No dead resources, no orphaned variables, no commented-out blocks. Every line ships or gets deleted. Every file is functional or deleted.
- **Secrets**: All sensitive values live in `.auto.tfvars` (git-ignored). SSH keys in `keys/` (git-ignored). ArgoCD password is bcrypt-hashed at apply time via `scripts/argocd_bcrypt.py` — the plaintext never persists.
- **Comments**: Use comments as needed in a standardized way, if a comment is lengthy, the code needs to be simplified first.

## CONVENTIONS

- Server names: `k3st-1..N`, agent names: `k3st-a1..N`.
- VM ID bases: servers 200+, agents 300+ (keep 100+ apart).
- Static IP bases: servers 10.0.0.230+, agents 10.0.0.240+.
- Storage references use Proxmox storage IDs (not mount paths).

## ANTI-PATTERNS

- Do not duplicate user/network config in cloud-init and `initialization`.
- Do not enable root login; use `vm_user` + sudo.
- Do not overlap IP ranges or VM ID ranges.
- Do not commit `.auto.tfvars` or keys.

## COMMANDS

```bash
terraform init
terraform plan
terraform apply
```

## NOTES

- Inventory is generated into `../k3s-ansible/inventory.ini` (don’t hand-edit).
- Template VM must have `qemu-guest-agent` installed/enabled.

<skills_system priority="1">

## Available Skills

<!-- SKILLS_TABLE_START -->
<usage>
When users ask you to perform tasks, check if any of the available skills below can help complete the task more effectively. Skills provide specialized capabilities and domain knowledge.

How to use skills:
- Invoke: `npx openskills read <skill-name>` (run in your shell)
  - For multiple: `npx openskills read skill-one,skill-two`
- The skill content will load with detailed instructions on how to complete the task
- Base directory provided in output for resolving bundled resources (references/, scripts/, assets/)

Usage notes:
- Only use skills listed in <available_skills> below
- Do not invoke a skill that is already loaded in your context
- Each skill invocation is stateless
</usage>

<available_skills>

<skill>
<name>artifacts-builder</name>
<description>Suite of tools for creating elaborate, multi-component claude.ai HTML artifacts using modern frontend web technologies (React, Tailwind CSS, shadcn/ui). Use for complex artifacts requiring state management, routing, or shadcn/ui components - not for simple single-file HTML/JSX artifacts.</description>
<location>global</location>
</skill>

<skill>
<name>artifacts-builder-windows</name>
<description>Windows-compatible suite of tools for creating elaborate, multi-component claude.ai HTML artifacts using modern frontend web technologies (React, Tailwind CSS, shadcn/ui). Use for complex artifacts requiring state management, routing, or shadcn/ui components on Windows systems - not for simple single-file HTML/JSX artifacts.</description>
<location>global</location>
</skill>

<skill>
<name>brainstorming</name>
<description>Use when creating or developing, before writing code or implementation plans - refines rough ideas into fully-formed designs through collaborative questioning, alternative exploration, and incremental validation. Don't use during clear 'mechanical' processes</description>
<location>global</location>
</skill>

<skill>
<name>browsing-windows</name>
<description>Windows-compatible browser automation using Chrome remote debugging with PowerShell. Launch Chrome with WebSocket debugging enabled for programmatic browser control. Use when you need to automate browser interactions, take screenshots, or test web applications on Windows.</description>
<location>global</location>
</skill>

<skill>
<name>condition-based-waiting</name>
<description>Use when tests have race conditions, timing dependencies, or inconsistent pass/fail behavior - replaces arbitrary timeouts with condition polling to wait for actual state changes, eliminating flaky tests from timing guesses</description>
<location>global</location>
</skill>

<skill>
<name>defense-in-depth</name>
<description>Use when invalid data causes failures deep in execution, requiring validation at multiple system layers - validates at every layer data passes through to make bugs structurally impossible</description>
<location>global</location>
</skill>

<skill>
<name>doc-coauthoring</name>
<description>Guide users through a structured workflow for co-authoring documentation. Use when user wants to write documentation, proposals, technical specs, decision docs, or similar structured content. This workflow helps users efficiently transfer context, refine content through iteration, and verify the doc works for readers. Trigger when user mentions writing docs, creating proposals, drafting specs, or similar documentation tasks.</description>
<location>global</location>
</skill>

<skill>
<name>docx</name>
<description>"Use this skill whenever the user wants to create, read, edit, or manipulate Word documents (.docx files). Triggers include: any mention of \"Word doc\", \"word document\", \".docx\", or requests to produce professional documents with formatting like tables of contents, headings, page numbers, or letterheads. Also use when extracting or reorganizing content from .docx files, inserting or replacing images in documents, performing find-and-replace in Word files, working with tracked changes or comments, or converting content into a polished Word document. If the user asks for a \"report\", \"memo\", \"letter\", \"template\", or similar deliverable as a Word or .docx file, use this skill. Do NOT use for PDFs, spreadsheets, Google Docs, or general coding tasks unrelated to document generation."</description>
<location>global</location>
</skill>

<skill>
<name>executing-plans</name>
<description>Use when partner provides a complete implementation plan to execute in controlled batches with review checkpoints - loads plan, reviews critically, executes tasks in batches, reports for review between batches</description>
<location>global</location>
</skill>

<skill>
<name>finishing-a-development-branch</name>
<description>Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for merge, PR, or cleanup</description>
<location>global</location>
</skill>

<skill>
<name>finishing-a-development-branch-windows</name>
<description>Windows-compatible guide for safely completing development branches with proper git workflows including testing, building, and cleanup. Use when finishing feature branches, preparing for merge/PR, or ensuring code quality before integration on Windows systems.</description>
<location>global</location>
</skill>

<skill>
<name>mcp-builder</name>
<description>Guide for creating high-quality MCP (Model Context Protocol) servers that enable LLMs to interact with external services through well-designed tools. Use when building MCP servers to integrate external APIs or services, whether in Python (FastMCP) or Node/TypeScript (MCP SDK).</description>
<location>global</location>
</skill>

<skill>
<name>pdf</name>
<description>Use this skill whenever the user wants to do anything with PDF files. This includes reading or extracting text/tables from PDFs, combining or merging multiple PDFs into one, splitting PDFs apart, rotating pages, adding watermarks, creating new PDFs, filling PDF forms, encrypting/decrypting PDFs, extracting images, and OCR on scanned PDFs to make them searchable. If the user mentions a .pdf file or asks to produce one, use this skill.</description>
<location>global</location>
</skill>

<skill>
<name>product-design-system</name>
<description>This skill should be used when designing product UIs from concept through implementation. It guides users through a structured 5-stage design process—from product requirements discovery to React + Tailwind implementation—ensuring design and UX are validated before any complex backend logic or authentication is built.</description>
<location>global</location>
</skill>

<skill>
<name>receiving-code-review</name>
<description>Use when receiving code review feedback, before implementing suggestions, especially if feedback seems unclear or technically questionable - requires technical rigor and verification, not performative agreement or blind implementation</description>
<location>global</location>
</skill>

<skill>
<name>requesting-code-review</name>
<description>Use when completing tasks, implementing major features, or before merging to verify work meets requirements - dispatches superpowers:code-reviewer subagent to review implementation against plan or requirements before proceeding</description>
<location>global</location>
</skill>

<skill>
<name>root-cause-tracing</name>
<description>Use when errors occur deep in execution and you need to trace back to find the original trigger - systematically traces bugs backward through call stack, adding instrumentation when needed, to identify source of invalid data or incorrect behavior</description>
<location>global</location>
</skill>

<skill>
<name>root-cause-tracing-windows</name>
<description>Windows-compatible tool for tracing root causes using pattern detection in test output. Uses git bisect and PowerShell to identify commits that introduced specific failures or debug output patterns. Use when debugging test failures or unexpected behavior on Windows systems.</description>
<location>global</location>
</skill>

<skill>
<name>sharing-skills</name>
<description>Use when you've developed a broadly useful skill and want to contribute it upstream via pull request - guides process of branching, committing, pushing, and creating PR to contribute skills back to upstream repository</description>
<location>global</location>
</skill>

<skill>
<name>sharing-skills-windows</name>
<description>Windows-compatible guide for sharing and contributing skills to team repositories with proper git workflows, packaging, and pull requests. Use when contributing skills to shared repositories or distributing custom skills to team members on Windows systems.</description>
<location>global</location>
</skill>

<skill>
<name>skill-creator</name>
<description>Guide for creating effective skills. This skill should be used when users want to create a new skill (or update an existing skill) that extends Claude's capabilities with specialized knowledge, workflows, or tool integrations.</description>
<location>global</location>
</skill>

<skill>
<name>systematic-debugging</name>
<description>Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes - four-phase framework (root cause investigation, pattern analysis, hypothesis testing, implementation) that ensures understanding before attempting solutions</description>
<location>global</location>
</skill>

<skill>
<name>template</name>
<description>Replace with description of the skill and when Claude should use it.</description>
<location>global</location>
</skill>

<skill>
<name>template-skill</name>
<description>Replace with description of the skill and when Claude should use it.</description>
<location>global</location>
</skill>

<skill>
<name>testing-anti-patterns</name>
<description>Use when writing or changing tests, adding mocks, or tempted to add test-only methods to production code - prevents testing mock behavior, production pollution with test-only methods, and mocking without understanding dependencies</description>
<location>global</location>
</skill>

<skill>
<name>testing-skills-with-subagents</name>
<description>Use when creating or editing skills, before deployment, to verify they work under pressure and resist rationalization - applies RED-GREEN-REFACTOR cycle to process documentation by running baseline without skill, writing to address failures, iterating to close loopholes</description>
<location>global</location>
</skill>

<skill>
<name>web-artifacts-builder</name>
<description>Suite of tools for creating elaborate, multi-component claude.ai HTML artifacts using modern frontend web technologies (React, Tailwind CSS, shadcn/ui). Use for complex artifacts requiring state management, routing, or shadcn/ui components - not for simple single-file HTML/JSX artifacts.</description>
<location>global</location>
</skill>

<skill>
<name>webapp-testing</name>
<description>Toolkit for interacting with and testing local web applications using Playwright. Supports verifying frontend functionality, debugging UI behavior, capturing browser screenshots, and viewing browser logs.</description>
<location>global</location>
</skill>

<skill>
<name>writing-plans</name>
<description>Use when design is complete and you need detailed implementation tasks for engineers with zero codebase context - creates comprehensive implementation plans with exact file paths, complete code examples, and verification steps assuming engineer has minimal domain knowledge</description>
<location>global</location>
</skill>

<skill>
<name>writing-skills</name>
<description>Use when creating new skills, editing existing skills, or verifying skills work before deployment - applies TDD to process documentation by testing with subagents before writing, iterating until bulletproof against rationalization</description>
<location>global</location>
</skill>

</available_skills>
<!-- SKILLS_TABLE_END -->

</skills_system>
