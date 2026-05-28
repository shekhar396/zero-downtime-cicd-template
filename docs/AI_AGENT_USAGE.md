# AI Agent Usage

AI tools such as Codex, coding agents, and LLM assistants may be used in this repository as pair-engineering support. They must not replace engineering judgment, review, or operational accountability.

## Appropriate Uses

AI may assist with:

- documentation drafts and edits
- boilerplate repository structure
- script scaffolding
- test generation ideas
- review suggestions
- risk checklists
- refactoring proposals
- explaining unfamiliar code paths

## Required Human Review

All AI-generated changes must be reviewed by a human maintainer before merge. Reviewers should verify correctness, security, maintainability, operational safety, and alignment with the repository roadmap.

## Secrets and Sensitive Data

Do not share secrets with AI tools. This includes:

- production credentials
- SSH private keys
- cloud tokens
- registry credentials
- customer data
- internal incident details that are not approved for external tools

Example files must use placeholders only.

## CI/CD Logic

Generated CI/CD logic must be tested before use. Pipeline stages, shell scripts, rollback commands, NGINX updates, and Docker commands can affect live systems if copied without review.

Production deployment commands must not be blindly trusted because they were produced by an AI assistant.

## Architecture Decisions

Architecture decisions must be approved by maintainers. AI can propose options and identify tradeoffs, but ownership for deployment strategy, risk acceptance, and production operation remains with humans.

## Operating Principle

AI can be used as a pair-engineering assistant. It must not be treated as an autonomous production operator.

