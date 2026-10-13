# Spec Delta

## ADDED Requirements

### Requirement: A long paragraph confirms its language at once
A language identified with confidence 0.8 or more for a text of at least 20 letters SHALL count as confirmed immediately, in addition to the rule that confirms a language seen in 3 of the last 10 reads. A confirmed language's missing model SHALL then be downloaded under the usual rules.

#### Scenario: One read of a French page
- **WHEN** no source languages are given, the French model is missing, and one read identifies a 120-letter paragraph as French with confidence 0.95
- **THEN** a download of French starts after that read

#### Scenario: Short text still needs repeats
- **WHEN** a 9-letter line is identified as Swahili with confidence 0.9 in one read
- **THEN** no download starts
