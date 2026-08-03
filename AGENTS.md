# Project guidelines

## Save data policy

- Backward compatibility for saved games is explicitly out of scope.
- When a persisted model changes, bump `GameEngine.saveKey` and treat older saves as unavailable.
- Do not add migrations, legacy decoding fallbacks, optional fields, or compatibility tests solely for older save formats.
- Optional values should represent current gameplay state only.

## Verification policy

- Do not run unit tests, UI tests, full test suites, balance simulations, or long-term simulations unless the user explicitly asks for tests.
- By default, limit verification to confirming that the app builds and, when relevant, launches without an immediate failure.
- A request to implement or fix something does not implicitly authorize running tests.
- Long-term tests require both an explicit user request and `RUN_LONG_TERM_TESTS=1`.
