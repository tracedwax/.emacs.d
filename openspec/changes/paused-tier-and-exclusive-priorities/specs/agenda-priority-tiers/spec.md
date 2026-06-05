## ADDED Requirements

### Requirement: Single active priority tier

A task SHALL carry at most one priority tier at any time. The tiers, from highest to lowest, are: On Fire, Bells Ringing, On Deck, Recently Considered, Paused. Setting a tier on a task that already has a different tier SHALL replace the previous tier rather than add to it. A task with no tier ("nothing") is a valid and common state.

#### Scenario: Set a tier on an untiered task
- **WHEN** the user invokes a tier on a task that has no priority tier
- **THEN** the task is given exactly that tier and no other

#### Scenario: Setting a tier replaces the previous one
- **WHEN** the user invokes a tier on a task that already has a different tier
- **THEN** the previous tier is removed and only the newly chosen tier remains

#### Scenario: Re-invoking the active tier clears it
- **WHEN** the user invokes the tier that the task already has
- **THEN** the task is returned to no tier ("nothing")

### Requirement: Each tier is set by a single key

In the agenda, each priority tier SHALL be assigned to a single key: `f` On Fire, `b` Bells Ringing, `d` On Deck, `c` Recently Considered, `p` Paused. These keys set the tier directly (subject to the single-active-tier rule); no other agenda key bindings change.

#### Scenario: Pressing a tier key sets that tier
- **WHEN** the user presses one of `f`, `b`, `d`, `c`, or `p` on a task in the agenda
- **THEN** the corresponding tier is applied to that task under the single-active-tier rule

#### Scenario: Existing non-tier keys are preserved
- **WHEN** the user presses `r` (refresh), `u`/`i` (cycle urgency/impact), `g`, or `l`
- **THEN** those commands behave exactly as before this change

### Requirement: Paused is the lowest tier

There SHALL be a Paused tier, displayed with the single glyph `🕐`, set by the key `p`, ranked as the lowest rung of the ladder — below Recently Considered. No tier ranks lower than Paused.

#### Scenario: Pausing a task
- **WHEN** the user presses `p` on a task
- **THEN** the task is given the Paused tier and any other tier it held is removed

#### Scenario: Paused ranks below all other tiers
- **WHEN** the agenda groups tasks by tier
- **THEN** the Paused group is ordered after the Recently Considered group

### Requirement: Tier section ordering and effort totals in agenda views

In each agenda view that groups tasks by tier, the tier sections SHALL appear in fixed highest-to-lowest order — On Fire, Bells Ringing, On Deck, Recently Considered, Paused — with the Paused section rendered last among the tier sections. Each tier section header, including Paused, SHALL display the summed effort of the tasks in that section.

#### Scenario: Paused section renders last
- **WHEN** a tiered agenda view is built and tasks exist in multiple tiers including Paused
- **THEN** the Paused section appears after the Recently Considered section in every such view

#### Scenario: Paused header shows an effort total
- **WHEN** the Paused section is rendered with one or more tasks
- **THEN** its header displays the summed effort of those tasks, in the same form as the other tier headers
