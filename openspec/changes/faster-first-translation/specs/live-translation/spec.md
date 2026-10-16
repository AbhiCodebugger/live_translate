# Spec Delta

## MODIFIED Requirements

### Requirement: A steady picture is read once
When the picture has been steady for at least 300 ms (each frame shifted by less than 1% of the frame's width and changed little beyond the shift), the live view SHALL read the latest frame once, with every selected script, paragraph by paragraph and in page colours, as freezing does, and show the result. It SHALL read again only as "A steady picture is read again until its language is settled" describes.

#### Scenario: Holding the phone over a page
- **WHEN** the picture has been steady for 300 ms over a French page
- **THEN** the latest frame is read once and its paragraphs are shown translated

#### Scenario: Not steady long enough
- **WHEN** the picture has been steady for 200 ms
- **THEN** nothing has been read yet

#### Scenario: Still steady after the read
- **WHEN** the result is shown with the source status ready, and the picture stays steady for 10 more seconds
- **THEN** no further frame is read

## ADDED Requirements

### Requirement: A steady picture is read again until its language is settled
While the picture stays steady and the source status is searching or guessed, the live view SHALL read the latest frame again 1 second after the previous read finished. It SHALL stop once the status is any other stage. The held labels SHALL stay shown until each new result replaces them.

#### Scenario: Short sign held still
- **WHEN** the picture is held steady on "Salida", each read identifies it as Spanish 0.9, and the Spanish model is missing
- **THEN** the frame is read three times about a second apart, Spanish is confirmed on the third read, and its download starts without the phone moving

#### Scenario: Settled language
- **WHEN** a read leaves the status ready for French and the picture stays steady
- **THEN** no further frame is read

#### Scenario: Nothing readable
- **WHEN** the picture is held steady on a Ukrainian page
- **THEN** three reads are made, the status becomes not found, and no further frame is read while the picture stays steady

#### Scenario: Movement interrupts
- **WHEN** the status is guessed and the picture starts moving before the next read
- **THEN** no read is made until the picture is steady again for 300 ms
