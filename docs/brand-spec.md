# Mischief magazine

Chosen direction: warm editorial satire, with one playful stamp and readable native controls.

| Token | Value |
|---|---|
| Paper canvas | `#F6F0E6` |
| Card stock | `#FFFCF6` |
| Primary ink | `#241E1C` |
| Secondary ink | `#6B6058` |
| Red accent | `#B52C2C` |
| Secondary accent | `#C76942` |
| Display type | System serif, bold/black |
| App icon | The approved black devil speech bubble with a copper smirk, on warm ivory |
| Body type | System default |
| Main spacing | 8 / 16 / 24 |
| Paper card radius | 20 |
| Action radius | 14 |
| Minimum touch target | 44 |

The existing Badvice mark remains available for exports and alternate themes. Default magazine surfaces use opaque paper, restrained shadows, dark text, and a solid red primary action. Motion should confirm a tap or a new take; respect system Reduce Motion and the app preference. Use Dynamic Type styles for content and maintain readable labels at accessibility sizes.

Regenerate the app icon set and 1024 px branding master with `swift scripts/render_badvice_icon.swift`. The checked-in `Resources/Branding/BadviceIcon-Approved-Source.png` is the high-resolution app-icon source. The renderer validates its dimensions and exports opaque PNGs at every catalog size, including the 1024 px marketing icon. The existing transparent in-app seal is preserved separately. The approved artwork was generated with the built-in image tool on November 17, 2026: a black devil speech bubble, copper smirk, and warm ivory background.
