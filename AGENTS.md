# AGENTS.md

## Project Purpose

Construct and maintain a reproducible data pipeline to assemble, clean, visualize, describe, and do inference on SNAP ABAWD Waiver and Dollar Store Entry Data. 

## Working Directory
- For now, only consider all items in the subfolder "Box". 

## Environment
- We will primarily use R to explore, transform, visualize and analyze data.
- Do not introduce Python or other languages unless explicitly requested.
- Avoid network calls unless explicitly instructed; assume required data are already present locally unless told otherwise.

## Pathing Rules
- Do not hardcode user-specific paths unless asked.
- All code should use a relative pathing regime.

## Pipeline Order (High-Level)
1. To be populated.

## Outputs
- Document every output file written by scripts, including ad hoc outputs.
- Default to non-destructive updates; do not overwrite existing outputs unless explicitly instructed.

## Documentation
- Keep README detailed and internally focused.
- Document legacy code in `1_code/legacy` in a separate README section.
- If adding new scripts, update the README with purpose, inputs, outputs, and dependencies.

## Safety
- Never run destructive git commands unless explicitly asked.
- If unexpected changes or ambiguities appear, stop and ask before proceeding.

## Communication
- Be concise and explicit about assumptions.
- Ask before writing outside the repository or making any network calls.

## Task-Specific Docs
- Task-specific routines and planning documents are contained in `agent-docs`.

./agent-docs/PLANS.md - Use this as a template in the planning phase.

./agent-docs/execplans/. - Use this subfolder to store plans we have finalized as a .md file. During the planning phase, I'll iterate on these files with you, which will then be used to execute workplans.

## README Governance and Automation Rules

Codex is authorized to update the README **only** within the boundaries defined below.  
Codex is not authorized to reinterpret project goals, redefine scope, or infer intent beyond explicit instructions.
Codex should only update the README when asked. When the README is to be updated, please follow the instruction set provided in /agent-docs/README_update_instructset.md.


## Reasoning & Scope Control
- Optimize for correctness, transparency and reproducibility over elegance.
- Do not introduce new estimators, identification strategies, variable constructions, or sample definitions unless explicitly requested.
- Never infer research intent from file names, directory structure, or reference documents.
