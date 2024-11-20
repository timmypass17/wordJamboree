# Word Jamboree
A fast-paced multiplayer word game where players type words with certain letters before time runs out, and the last one standing wins

<div style="display: flex; overflow-x: auto;">
    <img src="https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/6c/f5/76/6cf5764c-265f-6359-31bf-59cfaea92060/Simulator_Screenshot_-_iPhone_15_Pro_Max_-_2024-11-18_at_15.59.22.png/400x800bb.png" alt="Game Board" width="200" style="margin-right: 10px;">
    <img src="https://is1-ssl.mzstatic.com/image/thumb/PurpleSource221/v4/ea/f6/6f/eaf66fdc-e2e6-bb89-f495-0afab847fd37/simulator_screenshot_C9A351BD-57FA-40A6-A3DD-A0C7F26B03E3.png/400x800bb.png" alt="Home" width="200" style="margin-right: 10px;">
    <img src="https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/41/8e/0b/418e0b2b-9b8f-f1e2-2ccf-260b7b67ab37/Simulator_Screenshot_-_iPhone_15_Pro_Max_-_2024-11-18_at_16.00.29.png/400x800bb.png" alt="Chat" width="200" style="margin-right: 10px;">
    <img src="https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/2a/f7/d9/2af7d977-f6ce-a541-cb42-7f76cec5f7ac/simulator_screenshot_ACA524FB-CEB2-4D07-8A6B-87070819E4D4.png/400x800bb.png" alt="Guide" width="200" style="margin-right: 10px;">
</div>

## Features
- Compete Against Other Players
  - Join or host rooms for exciting matches with up to 5 players total.
- Dynamic Rounds
  - Start with easier words, but watch as the difficulty ramps up each round.
- Immersive Gameplay
  - Enjoy vibrant animations, sound effects, and visual cues for every move.
- Live Chat
  - Chat with opponents to strategize, encourage, or celebrate victories during and between rounds.

## Installation

### Prerequisites
- iOS 16.0+
- Xcode 15.4+

### Build Steps
1. Get a free API Key at [IsThereAnyDeal](https://isthereanydeal.com/)
2. Clone the repo
  ```sh
   git clone https://github.com/timmypass17/looting.git
   ```
3. Open `Topaz.xcodeproj` using Xcode.
4. Replace `apiKey` with your key

## Technologies used
- Swift
- UIKit (no storyboard)
- SwiftUI
  - Swift Charts
- XCTest
- Firebase
  - Firestore
  - Authentication
  - Cloud Functions
  - Messaging
- Node.js
- TypeScript

## Acknowledgements
All data used in this app is provided by
  - [IsThereAnyDeal](https://isthereanydeal.com/)
    - Source of game deal information
  - [GamerPower](https://www.gamerpower.com/)
    - Source of live giveaway data
  - [Steam Web](https://steamcommunity.com/dev)
    - Source of game details
