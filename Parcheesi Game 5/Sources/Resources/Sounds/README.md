# Sound Assets

Replace the placeholder `.wav` files below with production audio before App Store submission.

## Sound Effects (`AudioService.SoundEffect`)

| File | Trigger | Recommended Duration |
|------|---------|----------------------|
| `dice_roll.wav` | Dice roll animation | 0.5–0.8 s |
| `token_move.wav` | Token advances one square | 0.1–0.2 s |
| `token_enter.wav` | Token leaves yard and enters board | 0.3–0.5 s |
| `token_capture.wav` | Player captures an opponent token | 0.5–0.8 s |
| `token_home.wav` | Token reaches the home center | 0.6–1.0 s |
| `button_tap.wav` | UI button tap feedback | 0.05–0.1 s |
| `win_fanfare.wav` | Game-win celebration | 2.0–4.0 s |
| `lose_sting.wav` | Game-loss feedback | 1.0–2.0 s |
| `daily_reward.wav` | Daily login reward claimed | 0.8–1.2 s |

## Background Music

| File | Context | Notes |
|------|---------|-------|
| `music_menu.wav` | Main menu | Loop-able, upbeat |
| `music_game.wav` | In-game | Loop-able, moderate tempo |
| `music_victory.wav` | Win screen | Short, triumphant |

## Format Requirements

- **Format:** WAV (PCM) or CAF preferred for iOS; MP3/AAC also supported
- **Sample rate:** 44,100 Hz
- **Bit depth:** 16-bit
- **Channels:** Mono for SFX, Stereo for music
- **Volume:** Normalise SFX to –6 dBFS peak; music to –14 LUFS integrated

## Licensing

All audio must be either original work or licensed under a royalty-free license
that permits use in a commercial iOS application without attribution requirements.
Keep license receipts in `Docs/audio-licenses/`.
