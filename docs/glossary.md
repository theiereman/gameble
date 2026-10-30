# Glossary

The words the product and the code share, each with where it lives. Paths are
relative to the repository root; `catalog/` is short for `app/domains/catalog/app/`,
likewise `game/`, `accounts/` and `steam/`. For how the code is organised see
[architecture.md](architecture.md).

## Catalog

**Card.** One Steam game, identified by its Steam app (`source_key`). It holds
what never changes between seasons: release date, images, store URL, and its
text per locale. `Catalog::Card` (`catalog/models/catalog/card.rb`), texts in
`Catalog::CardText`. A card has a slug for its public page.

**Season.** A published edition of the catalog. A season is `draft` while the
staff builds it and `published` once it is live; every row attached to a
published season is frozen. Only one season is drawn from at a time (the
latest published one). `Catalog::Season`, `Catalog::PublishedSeason`,
`Catalog::DraftSeason`, operation `Catalog::PublishSeason`.

**Card-season.** A card as it exists in one season: its prestige score, rating,
review count, rarity, number and main theme for that season. Players hold
card-seasons, not bare cards, so the same game in two seasons is two
collectable items. `Catalog::CardSeason` (`catalog_card_seasons`).

**Prestige score.** The number computed from a game's Steam reviews that ranks
it inside a season. `Steam::PrestigeScore`, versions in `Catalog::ScoreVersions`.

**Rarity.** One of five levels, numbered 1 to 5: common, uncommon, rare, epic,
legendary. It is derived from the prestige score rank inside the season: the top
slices of the ranking become legendary, epic, rare and uncommon, the rest is
common. `Catalog::Rarity::TIERS`, cut points in `Catalog::RarityThresholds`.
The word "tier" is not used for rarity; see Tier below.

**Draw odds.** The chance of each rarity when a pack is filled, one table for
regular packs, one for bonus packs and one guaranteeing a rare or better.
`Game::DrawOdds`, `Game::Draw`, `Game::DrawPool` (the cards of the published season
grouped by rarity).

**Set.** A themed group of card-seasons of one season that players complete:
by theme, franchise, studio, the hall of fame, or the "ufo" set of games that fit no listed theme.
`Catalog::Set`, kinds in `Catalog::SetKind`, membership rows in
`Catalog::SetMembership`, names normalised by `Catalog::SetNames`, built by
`Catalog::SetBuilder`. A set page is the "album".

**Hall of fame.** A set kind whose members are picked by rating and review-count
rules (intouchables, pepites, mal-aimes, phenomenes). `Catalog::HallOfFame`.

**Theme.** A genre label used to group cards and name the main theme of a card-season.
Staff edit them in the back office. `Catalog::Theme`, `Catalog::TagClassification`.

**Tier (of a set).** A progress milestone inside a set, reached by holding enough
of its cards: five ranks (novice, apprentice, adept, expert, master) plus
`complete`, with the number of cards each needs set per set from its size.
Small sets have fewer tiers or none. `Catalog::SetTier`, thresholds computed by
`Catalog::TierTable`. A player's reached tiers are stored in `Game::SetTier`
(`game_set_tiers`), measured by `Game::SetStanding`.

**Staged batch.** A group of card-seasons being prepared for a draft season,
held in `Catalog::StagedCardSeason` until promoted into the draft season or
discarded. `Catalog::PromoteStagedBatch`, `Catalog::DiscardStagedBatch`.

**Roadmap.** The public list of milestones and stories shown on the landing
page and `/roadmap`. `Catalog::RoadmapMilestone`, `Catalog::RoadmapStory`,
`Catalog::PublicRoadmap`, edited in the back office.

## Steam import

**Import run.** One pass that fetches the Steam catalog in steps (app list,
reviews, tags, details, cards) page by page, into staging, and is then promoted
to a draft season. States include abandoned, failed, finished and promoted.
`Steam::ImportRun`, operations `Steam::StartImport`, `Steam::PromoteImport`...,
job `Steam::ImportStepJob`, back office at `import-runs`.

## Game

**Holding.** A player's quantity of one card-season (`quantity`; a row at zero
is not held), with the copies an open trade has set aside (`reserved`).
Duplicates are extra copies, and trades move them. `Game::Holding` (`game_holdings`), read through
`Game::Quantities`, `Game::HeldCopies`, `Game::HeldEditions`.

**Collection.** What a player holds, shown as a grid and an album per set.
`Catalog::CollectionGrid`, `Game::CollectionSummary`, `Game::CollectionTiles`.
The route is `/library`.

**Pack, booster, capsule.** One thing with three names. In the code it is a
`Game::Pack` (`game_packs`), five card-seasons drawn in advance
(`Game::Pack::SIZE`) and opened by the player. The route and the script call
the screen "booster" (`BoostersController`, `booster_controller.ts`). The
player-facing word in the interface is "capsule". A pack has a `kind`:
`regular` (the bank), `bonus` (daily bonus, three cards) or `reward` (community
goal). Opened by `Game::OpenPack`; opening publishes `Game::PackOpened`.

**Bank.** The player's stock of unopened regular packs, kept at ten
(`Game::Pack::BANK_SIZE`); a new pack becomes available every ten minutes
(`Game::Pack::INTERVAL`). Topped up by `Game::TopUpBank`, filled at sign-up by
`Game::FillBank`, repaired by `Game::HealBank` and `Game::TopUpBank.heal`.
Everything that touches a player's packs and holdings takes the bank lock,
`Game::BankLock`. Summaries in `Game::BankSummary` and `Game::BankSchedule`.

**Reserve.** The packs available to open right now (unopened, `available_at` in
the past). The reserve is "full" at ten, and a daily bonus is refused while it
is full. `Game::Reserve`; the chip in the header is `packs_chip`.

**Daily bonus.** One extra bonus pack a player can collect each day.
`Game::CollectDailyBonus`, claims in `Game::DailyBonusClaim`.

**Community goal (weekly goal).** A target of pack openings set for the whole
player base each week; when it is reached every contributor can claim a reward
pack. `Game::WeeklyGoal`, `Game::WeeklyContribution`, `Game::GoalReward`,
`Game::ClaimGoalReward`.

**First discovery (pioneer).** The first player ever to pull a card-season.
`Game::FirstDiscovery`, shown through `Game::PioneerOf`; the event is
`Game::CardDiscovered`.

**Showcase.** Up to five held cards a player pins to their public profile, in
a chosen order. `Game::ShowcaseEntry`, operations `Game::AddToShowcase`,
`Game::MoveShowcaseCard`, `Game::RemoveFromShowcase`.

**Repost.** Sharing a held card to the activity feed. Rate-limited per hour
and per card. `Game::RepostCard`, event `Game::CardReposted`, route `reposts`.

**Feed.** The activity stream of notable events: rare pulls, first discoveries,
trades, reposts and set tiers. Each row is a `Game::FeedEntry`
(`kind` is `pull`, `discovery`, `trade`, `repost` or `set`). It appears on the
feed page, the ticker and the landing page, and is pushed live by
`LiveStream` and `LiveFeedJob`.

**Trade.** An exchange of cards between two friends: one proposes, the other
accepts, declines or counters; an open trade expires after seven days. The
cards offered stay locked in the proposer's holding while it is open.
`Game::Trade`, `Game::TradeItem`, operations `Game::ProposeTrade`,
`Game::AcceptTrade`, `Game::CounterTrade`, `Game::DeclineTrade`,
`Game::CancelTrade`, `Game::ExpireTrade`. The screen is the trade board.

**Friend, invitation, friend code.** Friendship is mutual and starts from an
invitation, sent from a public profile or by a player's friend code (two groups
of four characters). `Game::Friendship`, `Game::Invitation`,
`Game::FriendCode`, `Game::SendInvitation`, `Game::AcceptInvitation`. Public
profile routes are named `brothers` for historical reasons.

**Achievement.** A badge unlocked by a milestone (first capsule, first epic,
openings counts...). `Game::Achievements` lists them,
`Game::GrantAchievement` unlocks one, `Game::AchievementUnlock` stores it.
An unlocked achievement waits, ready to collect, until the player clicks it on
the achievements screen: `Game::CollectAchievement` stamps it collected, and
only then does it count as earned and grant its card back.

**Card back.** The cosmetic back of a pack. Only the standard one exists today.
`Game::CardBacks`.

**First session guarantee.** The rule that a new player's first ten packs
contain at least one rare or better. `Game::FirstSessionGuarantee`.

**Welcome.** The first-visit panel a new player closes once.
`Accounts::CloseWelcome`, `WelcomesController`.

## Accounts

**Player.** A person signed in through Steam. Has a role (`player`, `moderator`,
`administrator`), a visibility and a last-seen time. `Accounts::Player`,
`Accounts::SignIn`, identity in `Steam::SignInIdentity`.

**Visibility.** Who can see a player: `public`, `friends_only` or `private`.
Changing it can cancel trades. `Accounts::SetVisibility`,
`Game::Visibility`, `Game::Handlers::VisibilityChanged`.

**Ban, report, moderation.** Staff can ban a player with a reason, and any player
can report another; staff work a report queue. `Accounts::BanPlayer`,
`Accounts::ReportPlayer`, `Accounts::Report`, `Accounts::ModerationAction`,
back office `bans` and `reports`.

**Retention.** Inactive players are deleted after a delay; deleted players'
games are released. `Accounts::ApplyRetentionJob`, `Accounts::DeleteInactivePlayer`,
`Game::ReleasePlayer`.

**Data export.** A player's downloadable copy of their data.
`Accounts::DataExport`, `PlayerExport`, `Accounts::RecordExport`.

## Engineering terms

**Operation.** A class `Domain::VerbNoun` that does one write and returns
`Success` or `Failure(:code)`. `ApplicationOperation`.

**Event, handler.** An operation publishes one event in its transaction;
handlers subscribed in `config/initializers/event_store.rb` react inside the
same transaction.

**Query.** A read the web layer calls, in a domain's `queries/` folder.

**Token.** The random public identifier of a record; database ids are never
exposed. `has_secure_token`.

**Stream.** A Turbo Stream broadcast to the browser: `LiveStream` for the shared
feed and community goal, `PlayerStream` for one player's own notifications.

**Root controller, state module.** The Stimulus controller that owns a screen
and the pure TypeScript module (`app/frontend/lib/<screen>.ts`) that holds its
state. See [architecture.md](architecture.md).
