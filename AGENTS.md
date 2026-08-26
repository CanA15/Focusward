# Agent Instructions

## Purpose

Produce code that is clear, small, necessary, and easy to test.

Do not add code that the task does not require. Do not add speculative features. Do not add an abstraction without a current need.

## Requirements

The user gives feature requirements in the task conversation.

- Treat the latest user instruction as the source of truth.
- Read the relevant source files, tests, and documentation before you make a change.
- Preserve current behavior unless the user requests a change.
- Do not invent product behavior.
- Ask the user when an unspecified decision can change visible behavior or stored data.
- Do not require a separate requirements document for a feature.

## Simplified Technical English

Use ASD-STE100 Simplified Technical English (STE) for prose.

This rule applies to:

- Agent messages
- Documentation
- Code comments
- User-interface text
- Error messages
- Commit messages

Follow these rules:

- Use short sentences.
- Use active voice.
- Give one instruction in each sentence.
- Use one term for one meaning.
- Use the same term throughout the project.
- Use common and specific words.
- Explain an abbreviation at its first use.
- Do not use slang.
- Do not use vague words.
- Do not use unnecessary adjectives.
- Do not omit articles or other required words.
- Do not use a pronoun when its reference is not clear.

Keep official names for application programming interfaces (APIs), frameworks, types, functions, and other code symbols.

## Work Method

Before you edit a file:

1. Inspect the Git worktree.
2. Identify changes that already belong to the user.
3. Read the code that controls the requested behavior.
4. Read the related tests.
5. State the intended change.
6. Select the smallest design that completes the task.

During the work:

- Make one logical change at a time.
- Keep unrelated user changes intact.
- Check each assumption against the code.
- Report an important nearby problem. Do not fix it without permission.
- Remove temporary diagnostics before completion.

## Test-First Development

Write the test before the implementation when an automated test can describe the behavior.

Use this sequence:

1. Write a focused test for the required behavior.
2. Run the test.
3. Confirm that the test fails for the expected reason.
4. Write the minimum code that makes the test pass.
5. Run the focused test again.
6. Refactor only when the code needs it.
7. Run all related tests.

For a defect, first add a test that reproduces the defect.

Do not add a test that checks an implementation detail. Test visible behavior and business rules.

Some SwiftUI layout and Safari automation behavior can require manual verification. In this case, extract and test the business logic first. Then verify the platform behavior manually. State what you verified.

Do not use real delays in a unit test. Pass controlled dates or a clock into time-based logic.

## Code Quality

- Prefer direct code over clever code.
- Keep one source of truth for each state value.
- Give each type and function one clear purpose.
- Use clear and specific names.
- Keep business rules out of SwiftUI views.
- Keep persistence logic at the persistence boundary.
- Keep Safari control logic at the automation boundary.
- Handle an error at the boundary that can act on it.
- Preserve user data after a recoverable error.
- Remove dead code and unused imports.
- Use existing project patterns when they remain suitable.

Do not add:

- A helper for one simple expression
- A wrapper that does not simplify behavior
- A protocol with no current need for another implementation
- A configuration option that the task does not require
- A compatibility path for an unsupported system
- A silent fallback that hides an error
- A third-party dependency when an Apple framework is sufficient

Do not refactor unrelated code. Do not rename unrelated symbols. Do not reformat unrelated files.

## Swift Rules

- Follow Swift naming conventions.
- Use value types for data and calculations when possible.
- Keep user-interface state on the main actor.
- Do not block the main actor.
- Use Swift concurrency correctly.
- Avoid force unwraps and force casts.
- Use early returns when they make conditions clear.
- Use the narrowest suitable access level.
- Do not make a symbol public without a requirement.
- Keep a SwiftUI view together when extraction does not improve clarity or reuse.

## Comments

Write a comment only when the reason is not clear from the code.

A useful comment explains one of these items:

- A product rule
- A safety condition
- A platform limitation
- A non-obvious design decision

Do not write a comment that repeats the code. Remove a comment when it is no longer correct.

## Product Boundaries

Focusward is a local Safari website blocker for macOS.

- Keep user data on the Mac.
- Do not add a server, analytics, telemetry, or a crash uploader.
- Do not add network access without explicit user approval.
- Do not store complete URLs, page paths, query parameters, page titles, or page contents.
- Extract only the hostname that the current operation requires.
- Do not log sensitive Safari data.
- Keep Safari as the only supported browser unless the user requests another browser.
- Treat Focusward as a friction tool. Do not describe it as a security boundary.

Update `docs/SECURITY.md` when a change affects stored data, permissions, networking, or privacy behavior.

## Verification

Use checks that are proportional to the change.

For a code change:

1. Run the focused tests during development.
2. Run all related tests after implementation.
3. Run the full test suite before completion when practical.
4. Review the complete diff.
5. Check for unnecessary code.
6. Check for unrelated changes.
7. Check affected documentation.

Use this command for the full test suite:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Focusward.xcodeproj \
  -scheme Focusward \
  -derivedDataPath /tmp/FocuswardDerived \
  -destination 'platform=macOS' \
  test
```

Do not state that a check passed unless the check completed successfully.

Documentation-only changes do not require the application test suite. Review the rendered text and the diff instead.

## Commits

Create one commit for each complete logical change.

A commit must:

- Have one clear purpose.
- Include the tests for its behavior.
- Pass its relevant checks.
- Exclude unrelated user changes.

Do not commit planning, temporary diagnostics, failed experiments, or incomplete work.

Use a short imperative subject. Examples include `Add daily allowance model` and `Fix session state restoration`.

Do not use a vague subject such as `Update code`, `Changes`, or `Fix stuff`.

Follow an explicit user request to combine commits or to make no commit.

## Completion

Work is complete only when:

- The requested behavior works.
- Existing behavior remains correct.
- The code contains no unnecessary parts.
- The tests cover the changed behavior.
- The relevant checks pass.
- The documentation is accurate.
- The privacy rules remain intact.
- The final summary states what changed and what was verified.
