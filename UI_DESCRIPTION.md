# Rewards Page UI Description

## Visual Layout

### Top Section: Points Display
```
┌─────────────────────────────────────┐
│   🟨 POINTS CARD (Amber Background) │
│                                      │
│          Your Points                 │
│             1,234                    │
│                                      │
└─────────────────────────────────────┘
```
- Amber colored card with user's current point balance
- Large, bold number display
- Real-time updates after wheel spin

### Middle Section: Daily Wheel Spin
```
┌─────────────────────────────────────┐
│      Daily Wheel Spin                │
│                                      │
│           ▼ (Red Arrow)              │
│                                      │
│       ╱──────────────╲               │
│      │  🎨 Wheel     │               │
│      │   6 Colored   │               │
│      │   Segments    │               │
│      │   10-500 pts  │               │
│      │               │               │
│       ╲──────────────╱               │
│                                      │
│     [Spin the Wheel! 🎰]            │
│   or                                 │
│     [Come back tomorrow! 💤]        │
│                                      │
└─────────────────────────────────────┘
```

#### Wheel Design:
- **Size**: 250x250 pixels
- **Segments**: 6 equal sections
- **Colors**:
  - 🔴 Red (10 points)
  - 🔵 Blue (25 points)
  - 🟢 Green (50 points)
  - 🟠 Orange (100 points)
  - 🟣 Purple (200 points)
  - 🔷 Teal (500 points)
- **Pointer**: Red downward arrow at top
- **Center Button**: "SPIN" text in circular purple button
- **Border**: White outline around wheel

#### Animation:
- Duration: 3 seconds
- Rotation: 5-7 full spins + landing position
- Easing: Smooth deceleration (easeOutCubic)

#### Button States:
1. **Available to Spin** (Purple button):
   - Text: "Spin the Wheel!"
   - Clickable
   - No message about next spin

2. **Already Spun Today** (Grey button):
   - Text: "Come back tomorrow!"
   - Disabled
   - Shows message: "Next spin available tomorrow!"

3. **Spinning** (Purple button):
   - Text: "Spinning..."
   - Disabled during animation

### Bottom Section: Available Rewards
```
┌─────────────────────────────────────┐
│      Available Rewards               │
│                                      │
│  ┌─────────────────────────────┐   │
│  │ 🎁  Reward 1       [Redeem] │   │
│  │     500 points               │   │
│  └─────────────────────────────┘   │
│                                      │
│  ┌─────────────────────────────┐   │
│  │ 🎁  Reward 2       [Redeem] │   │
│  │     600 points               │   │
│  └─────────────────────────────┘   │
│                                      │
│  ┌─────────────────────────────┐   │
│  │ 🎁  Reward 3       [Redeem] │   │
│  │     700 points               │   │
│  └─────────────────────────────┘   │
│                                      │
│  ┌─────────────────────────────┐   │
│  │ 🎁  Reward 4       [Redeem] │   │
│  │     800 points               │   │
│  └─────────────────────────────┘   │
│                                      │
└─────────────────────────────────────┘
```
- 4 reward cards
- Purple gift icon
- "Redeem" button enabled when user has enough points
- "Redeem" button disabled (greyed out) when insufficient points

## User Flow

### First Time User:
1. Opens Rewards tab
2. Sees 0 points
3. Wheel is available to spin
4. Taps "Spin the Wheel!" button
5. Wheel spins for 3 seconds
6. Lands on a reward (e.g., 100 points)
7. Dialog appears: "Congratulations! 🎉 You won 100 points!"
8. User taps "Awesome!"
9. Points update to 100
10. Button changes to "Come back tomorrow!"

### Next Day:
1. Opens Rewards tab
2. Sees accumulated points
3. Wheel is available again
4. Can spin once more

### Winning Different Amounts:
- Small wins: 10, 25 points
- Medium wins: 50, 100 points
- Large wins: 200, 500 points

## Responsive Behavior

- **Mobile Portrait**: Stacked vertical layout (as shown above)
- **Scroll**: SingleChildScrollView allows scrolling if content exceeds screen
- **Loading State**: Shows CircularProgressIndicator while fetching data
- **Error State**: Shows error message if database fetch fails

## Colors & Theme

- **Primary Color**: Deep Purple (Material Design)
- **Points Card**: Amber/Gold tones
- **Wheel Colors**: Vibrant primary colors
- **Background**: Follows app theme (light/dark mode)
- **Disabled Elements**: Grey

## Interactions

1. **Tap Wheel Center**: Initiates spin
2. **Tap Spin Button**: Initiates spin
3. **Tap Redeem Button**: (Not yet implemented - placeholder)
4. **Dialog Close**: Tap "Awesome!" to dismiss congratulations

## Accessibility

- Clear text labels
- Sufficient color contrast
- Button states clearly indicated
- Loading indicators for async operations
