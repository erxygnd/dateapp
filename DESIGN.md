# Fildir Design System

## Purpose

Fildir is a mobile-first social encounter app for missed real-life moments, anonymous interest, and mutual-match chat. The interface should feel intimate, cinematic, secretive, and emotionally safe.

This design direction is inspired by a dark "Secretly" style UI: deep plum backgrounds, hot-pink actions, soft blush text, glassy confession cards, compact match rows, and a premium anonymous mood.

## Brand Mood

- Secretive, warm, and emotionally charged.
- Modern dating app energy without feeling loud or childish.
- Anonymous first, human later.
- Night-city, private journal, whispered confession.
- Premium and focused, not playful arcade UI.

## Visual Keywords

- Dark romance
- Anonymous confession
- Soft neon pink
- Deep plum
- Blurred glass
- Quiet intimacy
- Rounded cards
- Subtle glow
- Mobile-first

## Core Palette

Use this palette as the primary visual language.

| Role | Hex | Usage |
| --- | --- | --- |
| App background | `#120D1A` | Main screen background |
| Background deep | `#0D0913` | Darkest areas, behind cards |
| Top bar | `#211020` | App bars and upper chrome |
| Bottom nav | `#1B1525` | Persistent navigation |
| Card surface | `#2A2333` | Match rows, panels, dialogs |
| Card elevated | `#34283D` | Active or raised surfaces |
| Confession plum | `#8A1E4D` | Card gradient highlight |
| Confession deep | `#171824` | Card gradient shadow |
| Primary pink | `#F30A68` | Main CTA, heart button, active nav |
| Pink glow | `#FF4D93` | Glow, notifications, focus states |
| Blush text | `#F5B5CE` | Brand text, soft headings |
| Primary text | `#F7EAF1` | Main readable text |
| Secondary text | `#A99AAA` | Supporting copy |
| Muted text | `#786D7C` | Labels, timestamps |
| Border subtle | `#433246` | Card borders and dividers |
| Danger/close | `#D9CAD5` | Dismiss icons on dark UI |

## Gradients

### App Background

Use a layered dark background:

- Base: `#120D1A`
- Top glow: transparent plum/pink near the top center
- Lower warmth: subtle brown-plum near the bottom

Flutter-friendly approximation:

```dart
LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF211020),
    Color(0xFF120D1A),
    Color(0xFF1A1018),
  ],
)
```

### Confession Card

The main encounter/confession card should use a vertical gradient:

```dart
LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF8A1E4D),
    Color(0xFF332033),
    Color(0xFF171824),
  ],
)
```

Add a subtle border:

```dart
Border.all(color: Color(0x33433246))
```

## Typography

Use high-contrast type on dark surfaces.

- App logo/name: serif or serif-like feel when possible, blush pink, bold.
- Screen titles: large, strong, emotional.
- Card quote text: italic, centered, soft blush or white.
- Labels: uppercase, spaced, small, muted blush.
- Body text: compact and readable.

Recommended Flutter style direction:

- Large title: 28-32, weight 800
- Screen title: 24-28, weight 800
- Card quote: 18-22, weight 700, italic
- Body: 14-16, weight 500
- Metadata: 11-12, weight 700, uppercase where appropriate

Do not use negative letter spacing. Keep letter spacing at `0` unless a small uppercase label needs slight spacing.

## Shape And Spacing

- Screen padding: 14-20 px.
- Top app bars: compact, dark, no heavy dividers.
- Main feature cards: 22-28 px radius.
- List cards: 6-10 px radius.
- Buttons: pill-shaped for primary CTA, circular for icon actions.
- Bottom nav: fixed, dark, slightly raised.
- Avoid nested cards. Each item should have one clear container.

## Component Rules

### Top App Bar

- Dark plum surface.
- Left: menu icon or back icon.
- Center/left: app name in blush pink.
- Right: notification icon with small hot-pink unread dot.
- Height should feel compact and app-like, not landing-page-like.

### Main Encounter Card

- Large vertical card, almost full screen width.
- Gradient from plum to dark.
- Rounded corners.
- Tiny horizontal handle near the top.
- Upper label: anonymous/confession category.
- Center: emotional quote or encounter text.
- Lower microcopy: "Swipe to reveal" or equivalent product action.
- Use minimal decoration; the text and gradient carry the mood.

### Action Buttons

Use three primary circular controls under the main card:

- Dismiss: dark circle with light close icon.
- Like: larger hot-pink circle with white heart icon.
- Comment/message: dark circle with light chat icon.

The like button should be visually dominant.

### Tags

- Small pill chips.
- Dark rose background.
- Blush or white text.
- Uppercase labels for emotional categories such as:
  - Vulnerability
  - Loneliness
  - Missed Moment
  - Mutual Interest

### Match List

- Dark surface cards with 6-10 px radius.
- Left avatar: circular, anonymous silhouette or blurred profile.
- Main text: name/title and short preview.
- Right: timestamp and chevron.
- Active/unread state: hot-pink dot near avatar or title.
- Category chip under preview.

### Primary CTA

- Hot-pink pill button.
- White text.
- Medium height, centered.
- Use for actions such as:
  - Explore More Secrets
  - Share A Moment
  - Send Interest
  - Continue

### Bottom Navigation

- Dark elevated bar.
- Four destinations maximum.
- Active item: hot-pink icon.
- Inactive items: muted blush/gray.
- Icons only are acceptable if the active state is clear.

## Screen Direction

### Splash

- Dark cinematic background.
- App logo/name in blush or hot pink.
- Short emotional phrase.
- Avoid bright daytime visuals.

### Login And Register

- Dark background.
- Compact form cards or unframed form blocks.
- Primary CTA in hot pink.
- Secondary links in blush.
- Keep copy emotional but trustworthy.

### Onboarding

- 3 short steps.
- Explain anonymity, nearby missed moments, and mutual-match chat.
- Use card-like visual metaphors rather than long text.

### Browse Encounters

- Main screen should resemble the large confession card reference.
- One primary card at a time.
- Tags below the action buttons.
- Keep browsing focused and thumb-friendly.

### Create Encounter

- Should feel like writing a private note.
- Dark text area surface.
- Category chips.
- Location/radius settings as compact controls.
- Primary button: hot-pink.

### Incoming Requests

- Use match-list style cards.
- Show anonymous identity, short context, timestamp, and action.
- Unread/new requests get a hot-pink indicator.

### Chat List

- Match-list reference style.
- Dark cards, avatars, timestamps, preview text.
- Primary CTA at bottom only when list is empty or needs discovery.

### Chat

- Dark intimate chat background.
- Mine bubbles: hot-pink or plum.
- Their bubbles: dark elevated surface.
- Composer: dark rounded input with pink send button.
- Safety/report actions must remain visible but quiet.

### Profile

- Dark surface.
- Photo grid with rounded tiles.
- Anonymous/profile controls grouped cleanly.
- Important actions in hot pink; destructive actions muted until confirmation.

### Settings

- Simple grouped rows.
- Theme selector should preview this dark pink direction.
- Keep toggles and account actions compact.

## Motion

- Use subtle animations only.
- Card reveal, like, dismiss, and notification states may use glow or scale.
- Avoid bouncy or cartoon-like motion.
- Transitions should feel smooth and private.

## Accessibility

- Maintain strong contrast on dark backgrounds.
- Do not place muted text on low-contrast plum surfaces.
- Minimum tappable target: 44 x 44 px.
- Use text labels where icons alone could be unclear.
- Do not rely only on color for unread or selected states.

## Flutter Implementation Notes

Map the current Flutter theme toward this palette:

- `AppColors.background` -> `#120D1A`
- `AppColors.backgroundSoft` -> `#211020`
- `AppColors.card` -> `#2A2333`
- `AppColors.cardSolid` -> `#34283D`
- `AppColors.inputFill` -> `#211B2B`
- `AppColors.border` -> `#433246`
- `AppColors.accent` -> `#F30A68`
- `AppColors.accentDark` -> `#C80755`
- `AppColors.secondary` -> `#FF4D93`
- `AppColors.violet` -> `#8A1E4D`
- `AppColors.violetDark` -> `#171824`
- `AppColors.text` -> `#F7EAF1`
- `AppColors.softText` -> `#A99AAA`

The implementation should keep Firebase, auth, chat, location, and data models unchanged. Only presentation widgets, theme colors, spacing, and UI composition should change unless a screen explicitly needs a new interaction.

## Stitch Prompt

Use this prompt when asking Stitch to continue the design:

```text
Design a mobile-first Flutter Material 3 UI for Fildir, an anonymous nearby encounter and mutual-match chat app.

Use a dark secretive romantic visual style inspired by anonymous confession apps:
deep plum background, hot-pink primary actions, blush typography, glassy gradient cards, compact match rows, and a premium intimate mood.

Palette:
background #120D1A, top bar #211020, bottom nav #1B1525, card #2A2333, elevated card #34283D, primary pink #F30A68, pink glow #FF4D93, blush text #F5B5CE, primary text #F7EAF1, secondary text #A99AAA, subtle border #433246.

Create real app screens, not a marketing page. Prioritize:
1. Browse nearby encounters as a large anonymous confession card
2. Match/chat list with compact dark cards
3. Create encounter post as a private note composer
4. Chat detail
5. Profile and settings

Keep the UI implementable in Flutter. Use icons, cards, bottom navigation, circular action buttons, chips, text fields, and clear empty/loading states.
```
