# Project guidelines

## Save data policy

- Backward compatibility for saved games is explicitly out of scope.
- When a persisted model changes, bump `GameEngine.saveKey` and treat older saves as unavailable.
- Do not add migrations, legacy decoding fallbacks, optional fields, or compatibility tests solely for older save formats.
- Optional values should represent current gameplay state only.
